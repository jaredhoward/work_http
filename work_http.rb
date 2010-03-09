require 'net/http'
require 'net/https'
require 'hpricot'

class WorkHTTP
  USERAGENT = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.14) Gecko/20080404 Firefox/2.0.0.14'
  attr_reader :resp, :data, :working_data
  attr_accessor :cookie

  def initialize(site, port=80)
   set_connection(site, port) 
  end

  def set_connection(site, port=80)
    @http = Net::HTTP.new(site, port)
    @http.read_timeout = 240
    if port == 443
      @http.use_ssl = true 
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end

  def headers
    @headers = {}
    @headers['Cookie'] = self.cookie unless self.cookie.nil?
    @headers['User-Agent'] = USERAGENT
    @headers['Keep-Alive'] = '300'
    @headers['Connection'] = 'keep-alive'
    return @headers
  end

  def get(page)
    @resp, @data = @http.get(page, self.headers)
    self.set_cookie
    return self.resp
  end

  def post(page, params)
    @resp, @data = @http.post(page, params, self.headers)
    self.set_cookie
    return self.resp
  end

  def set_cookie
    current_cookie = old_cgi_cookie_parse(@cookie)
    new_cookie = old_cgi_cookie_parse(self.resp['set-cookie'])
    unless new_cookie.nil?
      %w{path domain expires}.each {|title| new_cookie.delete title }
      current_cookie.update(new_cookie)
      @cookie = current_cookie.map {|key,value| "#{key}=#{value.map{|v| CGI.escape(v) }.join('&')}"}.join('; ') + ';'
    end
  end

  def logged_in?
    self.login if @logged_in.nil? || @logged_in == false
    @logged_in ||= false
  end

  def old_cgi_cookie_parse(raw_cookie)
    cookies = Hash.new([])
    return cookies unless raw_cookie

    raw_cookie.split(/[;,]\s?/).each do |pairs|
      name, values = pairs.split('=',2)
      next unless name and values
      name = CGI::unescape(name)
      values ||= ""
      values = values.split('&').collect{|v| CGI::unescape(v) }
      if cookies.has_key?(name)
        values = cookies[name].value + values
      end
      cookies[name] = CGI::Cookie::new({ "name" => name, "value" => values })
    end
    cookies
  end

  def log_data(filename, data=nil)
    f = File.new(File.join(RAILS_ROOT, 'log', filename), "w")
    f.write(data || "#{self.resp}\n\n\n#{self.data}")
    f.close
  end

end
