$LOAD_PATH.unshift File.join(__dir__, '../vendor/topology/lib')

require 'forwardable'
require 'optparse'
require 'path_manager'
require 'sliceable_switch'
require 'topology_controller'

# L2 routing switch
class RoutingSwitch < Trema::Controller
  extend Forwardable

  # Command-line options of RoutingSwitch
  class Options
    attr_reader :slicing

    def initialize(args)
      @opts = OptionParser.new
      @opts.on('-s', '--slicing') { @slicing = true }
      @opts.parse [__FILE__] + args
    end
  end

  timer_event :flood_lldp_frames, interval: 1.sec

  def_delegators :@topology, :flood_lldp_frames

  def slice
    fail 'Slicing is disabled.' unless @options.slicing
    Slice
  end

  # @!group Trema event handlers

  def start(args)
    @options = Options.new(args)
    @path_manager = start_path_manager
    @topology = start_topology
    logger.info 'Routing Switch started.'
  end

  def_delegators :@topology, :switch_ready
  def_delegators :@topology, :features_reply
  def_delegators :@topology, :switch_disconnected
  def_delegators :@topology, :port_modify

  def packet_in(dpid, message)
    @topology.packet_in(dpid, message)
    @path_manager.packet_in(dpid, message) unless message.lldp?
    #@topology.update_path(@path_manager.path)
  end

  private

  def start_path_manager
    fail unless @options
    (@options.slicing ? SliceableSwitch : PathManager).new.tap(&:start)
  end

  def start_topology
    fail unless @path_manager
    TopologyController.new.tap do |topology|
      mode = 'graphviz'
      file = '/tmp/topology.png'
      @command_line = CommandLine.new(logger)
      @command_line.parse [mode, file]
      topology.start @command_line
      #topology.start [mode,file]
      topology.add_observer @path_manager
      slice.add_observer @command_line.view
    end
  end
end
