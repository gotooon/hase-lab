# -*- coding: utf-8 -*-
require 'active_support/core_ext/class/attribute_accessors'
require 'json'
require 'path_manager'
require 'port'
require 'slice_exceptions'
require 'slice_extensions'

# Virtual slice.
# rubocop:disable ClassLength
class Slice
  extend DRb::DRbUndumped
  include DRb::DRbUndumped

  cattr_accessor(:all, instance_reader: false) { [] }

  def self.create(name)
    if find_by(name: name)
      fail SliceAlreadyExistsError, "Slice #{name} already exists"
    end
    new(name).tap { |slice| all << slice }
    maybe_send_slice_handler
  end

  def self.find_by(queries)
    queries.inject(all) do |memo, (attr, value)|
      memo.find_all do |slice|
        slice.__send__(attr) == value
      end
    end.first
  end

  def self.find_by!(queries)
    find_by(queries) || fail(SliceNotFoundError,
                             "Slice #{queries.fetch(:name)} not found")
  end

  def self.find(&block)
    all.find(&block)
  end

  def self.destroy(name)
    find_by!(name: name)
    Path.find { |each| each.slice == name }.each(&:destroy)
    all.delete_if { |each| each.name == name }
    maybe_send_slice_handler
  end

  def self.destroy_all
    all.clear
    maybe_send_slice_handler
  end

  # by yyynishi
  # (command) ./bin/slice merge -s slice1 -t slice2
  def self.merge(source_slice_name, target_slice_name)
    source_slice = find_by!(name: source_slice_name)
    target_slice = find_by!(name: target_slice_name)
 
    source_slice.each do |port, mac_addresses|
      mac_addresses.each do |mac_address|
        target_slice.add_mac_address(mac_address,
                                    dpid: port.dpid, port_no: port.port_no)
      end
    end
    destroy(source_slice_name) # delete source slice
  end

  # by yyynishi
  # (command) ./bin/slice split -s slice1 -t "slice2/11:11:11:11:11:11,22:22:22:22:22:22 slice3/33:33:33:33:33:33"
  def self.split(source_slice_name, target_slice_names) 
    source_slice = find_by!(name: source_slice_name)

    target_slice_a_name = target_slice_names.split(" ")[0].split("/")[0]
    target_slice_a_macs = target_slice_names.split(" ")[0].split("/")[1].split(",")

    target_slice_b_name = target_slice_names.split(" ")[1].split("/")[0]
    target_slice_b_macs = target_slice_names.split(" ")[1].split("/")[1].split(",")

    create(target_slice_a_name)
    create(target_slice_b_name)

    target_slice_a = find_by!(name: target_slice_a_name)
    target_slice_b = find_by!(name: target_slice_b_name)
    
    source_slice.each do |port, mac_addresses|
      mac_addresses.each do |mac_address|
        if target_slice_a_macs.include?(mac_address) then
          target_slice_a.add_mac_address(mac_address,
                                         dpid: port.dpid, port_no: port.port_no)
        elsif target_slice_b_macs.include?(mac_address) then
          target_slice_b.add_mac_address(mac_address,
                                         dpid: port.dpid, port_no: port.port_no)
        else
          fail("error in mac address")
        end
      end
    end
    destroy(source_slice_name)
  end

  def self.maybe_send_slice_handler
    @@observers.each do |each|
      if each.respond_to?(:slice_update)
        each.__send__ :slice_update, all
      end
    end
  end

  @@observers = []
  def self.add_observer(observer)
    @@observers << observer
  end

  attr_reader :name
  attr_reader :ports

  def initialize(name)
    @name = name
    @ports = Hash.new([].freeze)
  end
  private_class_method :new

  def add_port(port_attrs)
    port = Port.new(port_attrs)
    if @ports.key?(port)
      fail PortAlreadyExistsError, "Port #{port.name} already exists"
    end
    @ports[port] = [].freeze
  end

  def delete_port(port_attrs)
    find_port port_attrs
    Path.find { |each| each.slice == @name }.select do |each|
      each.port?(Topology::Port.create(port_attrs))
    end.each(&:destroy)
    @ports.delete Port.new(port_attrs)
  end

  def find_port(port_attrs)
    mac_addresses port_attrs
    Port.new(port_attrs)
  end

  def each(&block)
    @ports.keys.each do |each|
      block.call each, @ports[each]
    end
  end

  def ports
    @ports.keys
  end

  def add_mac_address(mac_address, port_attrs)
    port = Port.new(port_attrs)
    if @ports[port].include? Pio::Mac.new(mac_address)
      fail(MacAddressAlreadyExistsError,
           "MAC address #{mac_address} already exists")
    end
    @ports[port] += [Pio::Mac.new(mac_address)]
  end

  def delete_mac_address(mac_address, port_attrs)
    find_mac_address port_attrs, mac_address
    @ports[Port.new(port_attrs)] -= [Pio::Mac.new(mac_address)]

    Path.find { |each| each.slice == @name }.select do |each|
      each.endpoints.include? [Pio::Mac.new(mac_address),
                               Topology::Port.create(port_attrs)]
    end.each(&:destroy)
  end

  def find_mac_address(port_attrs, mac_address)
    find_port port_attrs
    mac = Pio::Mac.new(mac_address)
    if @ports[Port.new(port_attrs)].include? mac
      mac
    else
      fail MacAddressNotFoundError, "MAC address #{mac_address} not found"
    end
  end

  def mac_addresses(port_attrs)
    port = Port.new(port_attrs)
    @ports.fetch(port)
  rescue KeyError
    raise PortNotFoundError, "Port #{port.name} not found"
  end

  def member?(host_id)
    @ports[Port.new(host_id)].include? host_id[:mac]
  rescue
    false
  end

  def to_s
    @name
  end

  def to_json(*_)
    %({"name": "#{@name}"})
  end

  def method_missing(method, *args, &block)
    @ports.__send__ method, *args, &block
  end
end
# rubocop:enable ClassLength
