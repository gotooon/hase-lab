#最終課題(さいしゅうかだい)
##役割分担

* スライス分割、統合コマンドの作成: 西山
* スライス可視化: 後藤、中西、谷口
* レポート作成: 西山、後藤

##スライス操作関連コマンド作成
###スライス統合コマンド merge
以下のコマンドによりslice2に対してslice1を統合する。すなわちslice1を削除し、slice1に属するホストをslice2に移動させる。

`./bin/slice merge -s slice1 -t slice2`

`./bin/slice`に他のコマンド同様以下のコードを追加することでクラス`Slice`の関数`merge`を呼び出し、sliceの統合を行う。

    desc 'Merge a slice into other slice'
    ----- 他のコマンド同様、オプションの指定 -----
    c.action do |_global_options, options, _args|
    ----- 他のコマンド同様、エラー処理 -----
      Trema.trema_process('RoutingSwitch', options[:socket_dir]).
        controller.
        slice.
        merge(options[:sslice], options[:tslice])
      end
    end

`./lib/slice.rb`において、クラス`Slice`で以下のように関数`merge`を定義

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

'each'により、`-s`オプションで指定された`source_slice`内のすべての`mac_address`および`port`を`-t`オプションで指定される`target_slice`に`add_mac_address`関数により追加する。

###スライス分割コマンド split
以下のコマンドにより、slice1をslice2およびslice3に分割する。ここではslice1内のホストはmac addressにより指定され、またslice1内のすべてのホストが分割先スライスにおいて指定されていない場合、エラーを出力する。

`./bin/slice split -s slice1 -t "slice2/11:11:11:11:11:11,22:22:22:22:22:22 slice3/33:33:33:33:33:33"`

`./bin/slice`に他のコマンド同様以下のコードを追加することでクラス`Slice`の関数`split`を呼び出し、sliceの分割を行う。

    desc 'Split a slice into new slices'
    ----- 他のコマンド同様、オプションの指定 -----
    c.action do |_global_options, options, _args|
    ----- 他のコマンド同様、エラー処理 -----
      Trema.trema_process('RoutingSwitch', options[:socket_dir]).
        controller.
        slice.
        split(options[:sslice], options[:tslices])
      end
    end

`./lib/slice.rb`において、クラス`Slice`で以下のように関数`split`を定義

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

`each`により、`-s`オプションで指定される`source_slice`内の`mac_address`および`port`を`-t`で指定される`target_slice_a`および`target_slice_b`に振り分ける。


##スライス可視化
`routing_switch.rb`に graphviz モードを利用するように変更を加えた。

`slice.rb`では、graphviz をオブザーバとして加えて、
`self.maybe_send_handler`で graphviz にスライス情報を渡している。
基本的に、`slice.rb`内のスライス操作に応じて`maybe_send_handler`を
呼び出しているが、 add_port などの操作の場合は`bin/slice`内で呼び出している。

グラフ描画を行う`graphviz.rb`では、トポロジが変更された際の`update`メソッドによる
描画と、スライスを操作した際の`slice_update`メソッドによる描画が存在する。
それぞれで、トポロジとスライスの情報をインスタンス変数（@topology,@slices）に
保存しておくことで、`update`メソッドでトポロジ情報を、
`slice_update`メソッドでスライス情報を受け取ることができる。  
スライスの表示は以下のように行っている。

```ruby:graphviz.rb
	@slices.each_with_object({}) do |slice, tmp|
          slice_graph = gviz.add_graph("cluster_#{slice.name}", label: slice.name, style: 'dashed')
          slice.each do |port, mac|
            mac.each do |mac_address|
              slice_graph.add_nodes(mac_address.to_s, shape: 'ellipse')
            end
          end
        end
```

###謝辞
本課題を行うに当たって、スライス情報の受け渡し部分について、
渡辺研のプログラムを参考にさせて頂きました。

##動作確認

以下に作成した、merge、splitコマンド及び可視化による出力を記載する。

`routing_switch.rb` 起動後の初期状態の出力結果は以下の通りである。

![init](https://github.com/handai-trema/sliceable_switch-team-haselab/blob/master/figure/shoki.png)

host1からhost2へ、host2からhost1へそれぞれパケットを送信すると、host1とhost2が可視化される。

![step1](https://github.com/handai-trema/sliceable_switch-team-haselab/blob/master/figure/1and2.png)

2つのスライス(slice1,slice2)を作成し、それぞれにhost1,host2を追加した。

![step2](https://github.com/handai-trema/sliceable_switch-team-haselab/blob/master/figure/slice.png)

slice1,slice2をslice2に作成したmergeコマンドを利用して統合した。

![step3](https://github.com/handai-trema/sliceable_switch-team-haselab/blob/master/figure/slice_merged.png)

slice2をsplitコマンドを利用して、slice3とslice4に分割した。

![step4](https://github.com/handai-trema/sliceable_switch-team-haselab/blob/master/figure/slice_split.png)

以上より、プログラムが正常に動作していることを確認した。



