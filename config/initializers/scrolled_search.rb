module ScrolledSearch
  def scrolled_search(response, &block)
    body = {
      scroll_id: response["_scroll_id"]
    }
    until response["hits"]["hits"].empty?
      yield response["hits"]["hits"]
      response = $search[:main].scroll({
        scroll: "1m",
        body: body
      })
    end
    $search[:main].clear_scroll(body: body)
  end
end
