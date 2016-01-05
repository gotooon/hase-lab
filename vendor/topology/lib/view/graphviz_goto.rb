require 'graphviz'

module View
  # Topology controller's GUI (graphviz).
  class Graphviz
    def initialize(output = 'topology.png')
      @output = output
    end

    # rubocop:disable AbcSize
    def update(_event, _changed, topology)
      GraphViz.new(:G, use: 'neato', overlap: false, splines: true) do |gviz|
        nodes = topology.switches.each_with_object({}) do |each, tmp|
          tmp[each] = gviz.add_nodes(each.to_hex, shape: 'box')
        end
        
        topology.hosts.each do |each|
          ip_address = each[1].to_s
          dpid = each[2]
          hostnode = gviz.add_nodes(ip_address, shape: 'ellipse')
          next unless nodes[dpid]
          gviz.add_edges hostnode, nodes[dpid], dir: 'none'
        end

        topology.links.each do |each|
          next unless nodes[each.dpid_a] && nodes[each.dpid_b]
          gviz.add_edges nodes[each.dpid_a], nodes[each.dpid_b], dir: 'none'
        end

        topology.paths.each do |path|
          path.full_path.each_with_index {|each, index|
            break if path.full_path[index+1].nil?
            _current = path.full_path[index]
            _next = path.full_path[index+1]

            if _current.instance_of?(Topology::Port)
              break unless nodes[_current.dpid]
              from = nodes[_current.dpid]
            elsif _current.instance_of?(Pio::Mac)
              break unless gviz.find_node(_current.to_s)
              from = _current.to_s
            else next
            end
            if _next.instance_of?(Topology::Port)
              break unless nodes[_next.dpid]
              to = nodes[_next.dpid]
            elsif _next.instance_of?(Pio::Mac)
              break unless gviz.find_node(_next.to_s)
              to = _next.to_s
            else next
            end
            next if from == to

            gviz.add_edges(from, to, color: 'red', dir: 'forward')
          }
        end

        gviz.output png: @output
      end
    end
    # rubocop:enable AbcSize

    def to_s
      "Graphviz mode, output = #{@output}"
    end
  end
end
