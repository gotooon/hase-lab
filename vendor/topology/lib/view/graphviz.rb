require 'graphviz'

module View
  # Topology controller's GUI (graphviz).
  class Graphviz
    def initialize(output = 'topology.png')
      @output = output
      @topology = []
      @slices = []
    end

    # rubocop:disable AbcSize
    def update(_event, _changed, topology)
      GraphViz.new(:G, use: 'neato', overlap: false, splines: true) do |gviz|
        nodes = topology.switches.each_with_object({}) do |each, tmp|
          tmp[each] = gviz.add_nodes(each.to_hex, shape: 'box')
        end
        topology.links.each do |each|
          next unless nodes[each.dpid_a] && nodes[each.dpid_b]
          gviz.add_edges nodes[each.dpid_a], nodes[each.dpid_b], dir:'none'
        end

        unless @slices.empty?
        @slices.each_with_object({}) do |slice, tmp|
          slice_graph = gviz.add_graph("cluster_#{slice.name}", label: slice.name, style: 'dashed')
          slice.each do |port, mac|
            mac.each do |mac_address|
              slice_graph.add_nodes(mac_address.to_s, shape: 'elipse')
            end
          end
        end
        end

        host_nodes = topology.hosts.each_with_object({}) do |each, tmp|
          _mac_address, ip_address, dpid, _port_no = each
          if host_node = gviz.get_nodes(mac_address.to_s)
            tmp[each] = host_node
          else
            tmp[each] = gviz.add_nodes(_mac_address.to_s, shape: 'ellipse' )
          end
          gviz.add_edges tmp[each],nodes[dpid], dir: 'none'
        end
        
        #slice_color_type = ["black","red","green","yellow","blue","magenta","cyan","white"]
	#slice_colors = slices.each.with_index.each_with_object({})  do |(slice, i), tmp|
        #  color = slice_color_type[i % slice_color_type.length]
        #  if i < slice_color_type.length         
        #    slice = gviz.add_graph("cluster#{i}", color: color , style: "solid")
        #  elsif i <  slice_color_type.length * 2  
        #    slice = gviz.add_graph("cluster#{i}", color: color , style: "double")
        #  elsif i <  slice_color_type.length * 3  
        #    slice = gviz.add_graph("cluster#{i}", color: color , style: "dashed")
        #  elsif i <  slice_color_type.length * 4  
        #    slice = gviz.add_graph("cluster#{i}", color: color , style: "dotted")         
        #  else
        #    slice = gviz.add_graph("cluster#{i}", color: color , style: "solid")   
        #  end
        #  slice.ports.each do |port|
        #    slice.get_ports[port].each do |mac_address|
        #      tmp[mac_address.to_s] = color
        #      slice.add_nodes(mac_address.to_s, shape: 'box')
        #    end
        #  end          
        #end

        #slices.each do |slice|
        #  slice_graph = gviz.add_graph("cluster_#{slice.name}", label: slice.name, style: 'dashed')
        #  slice.each do |port, mac|
        #    mac.each do |mac_address|
        #      slice_graph.add_nodes(mac_address.to_s, shape: 'box')
        #    end
        #  end
        #end
      

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
            print "debug3 from:", from , " to:", to , "\n"
            gviz.add_edges(from, to, color: 'red', dir: 'forward')
          }
        end

        gviz.output png: @output
      end
      @topology = topology
    end
    
    # rubocop:enable AbcSize

    def slice_update(slices)
      GraphViz.new(:G) do |gviz|
        nodes = @topology.switches.each_with_object({}) do |each, tmp|
          tmp[each] = gviz.add_nodes(each.to_hex, shape: 'box')
        end
        @topology.links.each do |each|
          next unless nodes[each.dpid_a] && nodes[each.dpid_b]
          gviz.add_edges nodes[each.dpid_a], nodes[each.dpid_b], dir:'none'
        end

        slices.each_with_object({}) do |slice, tmp|
          slice_graph = gviz.add_graph("cluster_#{slice.name}", label: slice.name, style: 'dashed')
          slice.each do |port, mac|
            mac.each do |mac_address|
              slice_graph.add_nodes(mac_address.to_s, shape: 'elipse')
            end
          end
        end
        @slices = slices

        host_nodes = @topology.hosts.each_with_object({}) do |each, tmp|
          _mac_address, ip_address, dpid, _port_no = each
          if host_node = gviz.get_nodes(mac_address.to_s)
            tmp[each] = host_node
          else
            tmp[each] = gviz.add_nodes(_mac_address.to_s, shape: 'ellipse' )
          end
          gviz.add_edges tmp[each],nodes[dpid], dir: 'none'
        end
        
        gviz.output png: @output
      end
    end

    def to_s
      "Graphviz mode, output = #{@output}"
    end
  end
end
