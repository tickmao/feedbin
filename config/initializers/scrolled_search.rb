module ScrolledSearch
  def scrolled_search(response, &block)
    body = {
      scroll_id: response["_scroll_id"]
    }
    until response["hits"]["hits"].empty?
      yield response["hits"]["hits"]
      response = $search[:main].with do |client|
        client.scroll({
          scroll: "1m",
          body: body
        })
      end
    end
    $search[:main].with {|client| client.clear_scroll(body: body) }
  end
end
