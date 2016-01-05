require 'graphviz'

module View
  # Topology controller's GUI (graphviz).
  class Graphviz
    def initialize(output = 'topology.png')
      @output = output
    end

    # rubocop:disable AbcSize
    def update(_event, _changed, topology) #, slices)
      GraphViz.new(:G, use: 'neato', overlap: false, splines: true) do |gviz|
        nodes = topology.switches.each_with_object({}) do |each, tmp|
          tmp[each] = gviz.add_nodes(each.to_hex, shape: 'box')
        end
        topology.links.each do |each|
          next unless nodes[each.dpid_a] && nodes[each.dpid_b]
          gviz.add_edges nodes[each.dpid_a], nodes[each.dpid_b]
        end

        # h-goto (make slice graph)
       # slices.each_with_object({}) do |slice, tmp|
       #   slice_graph = gviz.add_graph("cluster_#{slice.name}", label: slice.name, style: 'dashed')
       #   slice.each do |port, mac|
       #     mac.each do |mac_address|
       #       slice_graph.add_nodes(mac_address.to_s, shape: 'elipse')
       #     end
       #   end
       # end

        host_nodes = topology.hosts.each_with_object({}) do |each, tmp|
          _mac_address, ip_address, dpid, _port_no = each
         # if host_nodes = gviz.get_nodes(mac_address.to_s)
         #   tmp[each] = host_nodes
         # else
            tmp[each] = gviz.add_nodes(_mac_address.to_s, shape: 'ellipse' )
         # end
          gviz.add_edges tmp[each],nodes[dpid], dir: 'none'
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
