require 'sinatra/base'
require 'cas_helpers'
require 'rack-flash'
require 'rack/csrf'
require_relative './userservice_test'

class CasExample < Sinatra::Base
  #use Rack::Session::Cookie, :secret => 'changeme' #using session cookies in production with CAS is NOT recommended
  enable :sessions
  use Rack::Csrf, :raise => true
  use Rack::Flash, :sweep => true
  helpers CasHelpers

  #use Rack::Flash
  set :environment, :production
  set :erb, :layout => false
  #set :root, File.dirname(__FILE__)
  set :root, File.expand_path('.')
  set :views, Proc.new { File.join(root, "lib/views") }
  set :public_folder, Proc.new { File.join(root, "static") }
  @@us = UserService.new
  @@service_url = 'http://localhost:3000'
  before do    
    process_cas_login(request, session)    
  end

  get "/" do   
    puts "ticket: #{session[:cas_ticket]}"  
    if !logged_in?(request, session) then       
      erb :index
    else      
      erb :home
    end
  end
  post "/reset" do
    redirect '/'  if logged_in?(request, session)
    email = params[:user][:email].gsub(/\s+/, "")
    v = @@us.resetpassword(email)
    case v[:code]
    when -2
      flash[:error] = v[:msg]
    when -1 
      flash[:error] = v[:msg]
    when 1
      flash[:success] = v[:msg]      
    end
    redirect "/"
  end
  get "/redirect" do
    require_authorization(request, session) unless logged_in?(request, session)    
    redirect '/'
  end
  
  post "/" do 
    #redirect "/" unless logged_in
    'hello'
  end
  get "/activate/:token" do |token|
    v = @@us.confirm_register(token)
    case v[:code]
    when -2
        flash[:error] = v[:msg]        
    when -1
        flash[:error] = v[:msg]        
    when 0
        flash[:error] = v[:msg]        
    when 1
        flash[:success] = v[:msg]        
    when 2
        flash[:notice] = v[:msg]        
    end    
    redirect "/"
  end
  # post register
  post "/signup" do
    redirect "/" if logged_in?(request, session)


    email = params[:user][:email].gsub(/\s+/, "")
    password = params[:user][:password].gsub(/\s+/, "")
    password2 = params[:user][:password2].gsub(/\s+/, "")
    

    if password == password2 then             
      hovaten = params[:user][:hovaten].strip
      ngaysinh = params[:user][:ngaysinh]
      #hovaten, ngaysinh, diachi, gioitinh, sodienthoai
      diachi = params[:user][:diachi]
      gioitinh = params[:user][:gioitinh]
      sodienthoai = params[:user][:sodienthoai].strip
      msv = params[:user][:msv].strip
      begin
            xngaysinh = Date.strptime(ngaysinh.strip, '%d/%m/%Y')
      rescue
          flash[:error] = "Vui long nhap ngay thang theo dinh dang NGAY/THANG/NAM (18/07/1987)"
          redirect "/"
      end
      xprofile = {
        :email => email,
        :hovaten => hovaten,
        :ngaysinh => xngaysinh,
        :diachi => diachi,
        :gioitinh => gioitinh,
        :sodienthoai => sodienthoai}

      if !msv.empty?  then 
        v = @@us.register_student(msv, email, password, xprofile)
      else
        v = @@us.register_guest(email, password, xprofile)
      end

      if v[:code] == 1 then 
        flash[:success] = "Message saved successfully."
        redirect "/"
      else 
        flash[:error] = "Khong ton tai ma sinh vien va email"
        redirect "/"
      end
    else
      flash[:error] = "Password khong trung"
      redirect "/"
    end
  end
  get "/logout" do    
    session[:cas_user] = ''
    session[:cas_ticket] = ''
    puts "logout: #{session[:cas_ticket]}"     
    redirect logout_url
  end
  
  helpers do
     def logged_in?(request, session)
      session[:cas_ticket] && !session[:cas_ticket].empty?    
    end
    def flash_types
      [:success, :notice, :warning, :error]
    end
    def login_url 
      "http://acc.hpu.edu.vn/login?service=#{@@service_url}/redirect"
    end
    def logout_url
      "http://acc.hpu.edu.vn/logout?service=#{@@service_url}"
    end
  end
end
