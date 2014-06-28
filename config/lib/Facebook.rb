class Facebook
  def self.api_call(call_type, url, query)
    case call_type
    when 'get'
      resp = HTTParty.get(url, {:query => query})
    when 'post'
      resp = HTTParty.post(url, {:query => query})
    end
    ret = {
      :status => {
        :success => true
      }
    }
    if resp['error']
      ret[:status][:success] = false
      ret[:status][:err_type] = resp['error']['type']
    else
      ret[:data] = resp
    end
    return ret
  end
end