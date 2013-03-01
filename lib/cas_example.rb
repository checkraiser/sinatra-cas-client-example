# encoding: UTF-8
require 'sinatra/base'
require 'cas_helpers'
require 'rack-flash'
#require 'rack/csrf'
#require_relative './userservice_test'
require_relative './userservice'
class CasExample < Sinatra::Base
  #use Rack::Session::Cookie, :secret => 'changeme' #using session cookies in production with CAS is NOT recommended
  enable :sessions
  #use Rack::Csrf, :raise => true
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
  @@service_url = 'http://10.1.0.195:3000'  
  @@cas_url = 'http://10.1.0.195:3001'
  before do    
    process_cas_login(request, session)    
  end
  error 400..510 do
    'Boom'
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
  # change profile
  post "/" do 
    #redirect "/" unless logged_in
    email = params[:profile][:email].strip
    hovaten = params[:profile][:hovaten].strip
    ngaysinh = params[:profile][:ngaysinh]
    #hovaten, ngaysinh, diachi, gioitinh, sodienthoai
    diachi = params[:profile][:diachi]
    gioitinh = params[:profile][:gioitinh]
    dienthoai = params[:profile][:dienthoai].strip
    
    begin
          xngaysinh = Date.strptime(ngaysinh.strip, '%d/%m/%Y')
    rescue
        flash[:error] = "Vui lòng nhập ngày tháng theo định dạng ngày/tháng/năm (ví dụ: 18/05/1990)"
        redirect "/"
    end
    xprofile = {
      :email => email,
      :hovaten => hovaten,
      :ngaysinh => xngaysinh,
      :diachi => diachi,
      :gioitinh => gioitinh,
      :dienthoai => dienthoai}
    v = @@us.changeprofile(session[:cas_user], xprofile)
    case v[:code]
    when -1
      flash[:error] = v[:msg] 
    when 1
      flash[:success] = v[:msg]
    end
    redirect "/"
  end
  post '/reconfirm' do
    begin
      v = @@us.reconfirm(session[:cas_user])
      case v[:code]
      when -1
         flash[:error] = v[:msg]
      when -2
         flash[:error] = v[:msg]
      when 1
          flash[:success] = v[:msg]
      when 2
         flash[:notice] = v[:msg]
      end
      redirect '/'
    rescue
      flash[:error] = "Co loi xay ra"
      redirect "/"
    end
  end
  # change password
  post "/changepassword" do
    oldpassword = params[:user][:oldpassword].strip
    newpassword = params[:user][:password].strip
    newpassword2 = params[:user][:password2].strip
    v = @@us.changepassword(session[:cas_user], oldpassword, newpassword, newpassword2)
    case v[:code]
    when -1
      flash[:error] = v[:msg]
    when 1
      flash[:success] = v[:msg]
    end      
    redirect '/'
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
    if @@us.get_user(email) then
      flash[:warning] = 'Email nay da ton tai'
      redirect '/'
    end
    password = params[:user][:password].gsub(/\s+/, "")
    password2 = params[:user][:password2].gsub(/\s+/, "")
    

    if password == password2 then            

      if password.length < 6 then
        flash[:warning] = 'Mật khẩu quá ngắn, phải có ít nhất 6 ký tự'
        redirect '/'
      end 
      
      msv = params[:user][:msv].strip  unless params[:user][:msv].empty?      
      xprofile = {
        :email => email
      }

      if msv && !msv.empty?  then 
        xprofile[:masinhvien] = msv
        #xprofile = xprofile.merge!(xxprofile) if xxprofile          
        v = @@us.register_student(msv, email, password, xprofile)
      else
        v = @@us.register_guest(email, password, xprofile)
      end

      if v[:code] == 1 then 
        flash[:success] = v[:msg]
        redirect "/"
      else 
        flash[:error] = v[:msg]
        redirect "/"
      end
    else
      flash[:error] = "Mật khẩu xác nhận không trùng"
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
      "#{@@cas_url}/login?service=#{@@service_url}/redirect"
    end
    def logout_url
      "#{@@cas_url}/logout?service=#{@@service_url}"
    end
    def current_user
      @@us.get_user(session[:cas_user])
      #session[:cas_user]
    end
    def current_profile
      @@us.get_profile(session[:cas_user])
    end
    def current_services
      @@us.get_services(session[:cas_user])
    end    
  end
end
