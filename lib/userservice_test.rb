# encoding: UTF-8
require 'savon'
require 'celluloid'
require_relative './workers/mailservice'
require_relative './models_test'

class UserService
	include Celluloid
	def initialize
		@client = Savon.client(wsdl: "http://10.1.0.238:8082/HPUWebService.asmx?wsdl")		
	end
	def getemail(msv)	
		return '' if msv.blank?	
		response = @client.call(:thong_tin_sinh_vien) do		
			message(masinhvien: msv)
		end
		res_hash = response.body.to_hash
		
		ls = res_hash[:thong_tin_sinh_vien_response][:thong_tin_sinh_vien_result][:diffgram][:document_element];
		if (ls != nil) then 	
			ls = ls[:thong_tin_sinh_vien]				
			return  ls[:email].strip if ls[:email]			
		else
			return ''
		end
	end
	def getprofile(email, msv)	
		return '' if msv.blank?	
		profile = Profile.first_or_create(:email => email)	  	

	  	
		response = @client.call(:thong_tin_sinh_vien) do		
			message(masinhvien: msv)
		end
		res_hash = response.body.to_hash
		result = {}
		ls = res_hash[:thong_tin_sinh_vien_response][:thong_tin_sinh_vien_result][:diffgram][:document_element];
		if (ls != nil) then 	
			ls = ls[:thong_tin_sinh_vien]				
			result[:email] = ls[:email].strip if ls[:email]			
			result[:hovaten] = "#{ls[:ho_dem].strip} #{ls[:ten].strip}" if ls[:ho_dem] and ls[:ten]
			begin
				ngaysinh = ls[:ngay_sinh].strip if ls[:ngay_sinh]
		        xngaysinh = Date.strptime(ngaysinh, '%d/%m/%Y')
		    rescue
		       puts "ngay sinh ko hop le"
		    end
			result[:ngaysinh] = xngaysinh
			result[:gioitinh] = 1 if ls[:gioi_tinh] && ls[:gioi_tinh].strip == 'Nam'
			result[:gioitinh] = 0 if ls[:gioi_tinh] && ls[:gioi_tinh].strip == 'Nữ'
			result[:diachi] = ls[:dia_chi].strip if ls[:dia_chi]
			result[:dienthoai] = ls[:dien_thoai].strip if ls[:dien_thoai]
			
			if profile
	  			profile.attributes = result
	  			begin 
	  				profile.save
	  			rescue
	  				puts "get student profile error"
	  			end
	  		end
		else
			return nil
		end
	end
	def checksv(email, msv)		
		mail = getemail(msv)		
		return email == mail
	end
	def checkgv(email)
		return Teacher.first(:email => email) != nil
	end
	def get_user(email)
		return User.first(:email => email)
	end	
	def get_profile(email)
		user = get_user(email)
		return Profile.first(:user_id => user.id)
	end
	def get_services(email)
		user = get_user(email)
		return user.role.services if user
		return nil if user == nil
	end
	def confirm_register(token) #tested
		# xac nhan dang ky va kich hoat thanh cong
		# tham so la token
		# result:
		# - code: 1: thanh cong, 0: that bai, -1: qua han
		# thuat toan:
		# - get token tu bang Activation
		# - mo thread moi xu ly tat ca token truoc cua user day
		# - tao token moi va sendmail xac nhan
		token = token.strip unless token.blank?
		activate_token = Activation.first(:token => token)
		if activate_token then 
			if activate_token.created_at + 3*3600*24 <= DateTime.parse(Time.now.to_s) # expire
				return {:code => -1, :msg => 'Vé đăng ký đã quá hạn, vui lòng đăng nhập để kích hoạt lại.'} # expired
			end
			user = activate_token.user
			if user == nil then return {:code => 0, :msg => 'Tài khoản này không tồn tại, vui lòng đăng ký'} end
			if user.status == 0  then 
				user.status = 1 
				activate_token.token = Time.now.to_s
				activate_token.status = 1				
				if user.save and activate_token.save then return {:code => 1, :msg => 'Tài khoản này đã kích hoạt, vui lòng đăng nhập'} end
			else
				return {:code => 2, :msg => 'Tài khoản này đã kích hoạt, vui lòng đăng nhập'}
			end
		end
		return {:code => -2, :msg => 'Unknown error'}
	end
	def reconfirm(email)
		begin
			email = email.strip unless email.blank?
			user = get_user(email)
			return {:code => -1, :msg => 'Tài khoản này không tồn tại, vui lòng đăng ký'} if user == nil 
			return {:code => 2, :msg => 'Tài khoản này đã kích hoạt'} if user.status == 1
			register_confirm = Activation.new(:token => SecureRandom.hex, :created_at => Time.now, :description => 'Register reconfirmation', :status => 0)			 
			register_confirm.user = user
			if user.save and register_confirm.save then 
				sm = SendEmail.new({:to => email, :token => register_confirm.token, :reason => 'register'})
				sm.async.perform
				return {:code => 1, :msg => 'Một email kích hoạt đã được gởi đến hòm thư của bạn, vui lòng kiểm tra thư để kích hoạt'}
			end
		rescue
			return {:code => -2, :msg => 'Unknown error'}
		end
	end	
	def changepassword(email, old, p, p2)
		begin
			email = email.strip unless email.blank?
			return {:code => -1, :msg => 'Mật khẩu quá ngắn, phải có ít nhất 6 ký tự'} if (p.length < 6 or p2.length < 6)
			return {:code => -1, :msg => 'Mat khau moi khong trung'} if (p != p2)
			xold = hash_pass(old)
			xp = hash_pass(p)
			user = get_user(email)
			return {:code => -1, :msg => 'Mật khẩu xác nhận không trùng'} if (user[:password] != xold)
			user.password = xp
			if user.save 
				return {:code => 1, :msg => 'Mật khẩu đã cập nhật thành công'}
			end
		rescue
			return {:code => -2, :msg => 'Unknown error'}
		end
	end
	def resetpassword(email)
		begin			
			email = email.strip unless email.blank?			
			user = get_user(email)
			return {:code => -1, :msg => 'Không tồn tại tài khoản với email này'}
			newpass = generate_password(8)
			user.password = hash_pass(newpass)
			if  user.save					
				sm = SendEmail.new({:to => email, :token => newpass, :reason => 'reset'})
	  			sm.async.perform
	  			return {:code => 1, :msg => 'Một email kèm thông tin tài khoản đã được gởi đến hòm thư của bạn, vui lòng kiểm tra thư'}
			else
				return {:code => -1, :msg => 'Tài khoản này không tồn tại, vui lòng thử lại'}
			end
		rescue
			return {:code => -2, :msg => 'Unknown error'}
		end
	end
	def changeprofile(email, xprofile)
		begin			
			user = get_user(email)
			return {:code => -1, :msg => 'Tài khoản này không tồn tại, vui lòng đăng ký'} if user == nil
			profile = Profile.first(:user_id => user.id)
			return {:code => -1, :msg => 'Hồ sơ không tồn tại'} if profile == nil			
			profile.attributes = {:hovaten => (xprofile[:hovaten] if xprofile.has_key?(:hovaten)),
				:gioitinh => (xprofile[:gioitinh] if xprofile.has_key?(:gioitinh)),
				:ngaysinh => (xprofile[:ngaysinh] if xprofile.has_key?(:ngaysinh)),
				:diachi => (xprofile[:diachi] if xprofile.has_key?(:diachi)),
				:noicongtac => (xprofile[:noicongtac] if xprofile.has_key?(:noicongtac)),
				:email => (xprofile[:email] if xprofile.has_key?(:email)),
				:dienthoai => (xprofile[:dienthoai] if xprofile.has_key?(:dienthoai))}
			if profile.save				
				return {:code => 1, :msg => 'Hồ sơ cập nhật thành công'}
			end
		rescue
			return {:code => -1, :msg => 'Unknown error'}
		end
	end
	def register(email, password, role, xprofile)
		# dang ky moi voi tu cach thanh vien cung role tuong ung
		# 
		# thuat toan:
		# - lay role tuong ung voi role
		begin
			return {:code => 1, :msg => 'Registered'}  if get_user(email)
			role_guest = Role.first_or_create(:name => role)
			user = User.new(:email => email, :password => hash_pass(password), :status => 0,  :created_at => Time.now)
			user.role = role_guest
		  	profile = Profile.first_or_create(:email => user[:email])
		  	profile.user = user		  
		  	if xprofile
		  		profile.attributes = {:hovaten => (xprofile[:hovaten] if xprofile.has_key?(:hovaten)),
				:gioitinh => (xprofile[:gioitinh] if xprofile.has_key?(:gioitinh)),
				:ngaysinh => (xprofile[:ngaysinh] if xprofile.has_key?(:ngaysinh)),
				:diachi => (xprofile[:diachi] if xprofile.has_key?(:diachi)),
				:noicongtac => (xprofile[:noicongtac] if xprofile.has_key?(:noicongtac)),
				:email => (xprofile[:email] if xprofile.has_key?(:email)),
				:dienthoai => (xprofile[:dienthoai] if xprofile.has_key?(:dienthoai)),
			}
		  	end
		  
			register_confirm = Activation.new(:token => SecureRandom.hex, :created_at => Time.now, :description => 'Register confirmation', :status => 0)			 
			register_confirm.user = user
		  	user.masinhvien = xprofile[:masinhvien] if xprofile.has_key?(:masinhvien)
		  
		    if user.save and register_confirm.save and profile.save and register_confirm.save		
			  	#Resque.enqueue(SendEmail, email, register_confirm.token, 'register')
			  	sm = SendEmail.new({:to => email, :token => register_confirm.token, :reason => 'register'})
			  	sm.async.perform			  	
			  	self.async.getprofile(email, user.masinhvien) if xprofile.has_key?(:masinhvien)
			  	#sendmail(user.email, register_confirm.token, :registermail)
			    #session[:user] = user.email
			    return {:code => 1, :msg => 'Một email kích hoạt đã được gởi đến hòm thư của bạn, vui lòng kiểm tra thư để kích hoạt đăng ký'}
			end
	    rescue
	  	  return {:code => -1, :msg => 'Unknown Error'}
	    end
	end	
	def register_guest(email, password, xprofile)				
		gvtest = checkgv(email)		
		if gvtest			
			return register(email, password, 'Teacher', xprofile)
		else
			return register(email, password, 'Guest', xprofile)
		end
	end
	def register_student(sis, email, password, xprofile)

		svtest = checksv(email, sis)
		if svtest
			if email.include?("hpu.vn")
			return {:code => -1, 
				:msg => "Email #{email} không thể sử dụng, http://hpu.edu.vn/sinhvien để cập nhật email"} 
			end
			#password = hash_pass(Digest::MD5.hexdigest(generate_password))
			return register(email, password, 'Student', xprofile)
		else
			return {:code => -1, :msg => 'Unknown MSV'}
		end
	end	
	
	
	def generate_password(size = 6)
	  charset = %w{ 2 3 4 6 7 9 A C D E F G H J K M N P Q R T V W X Y Z}
	  (0...size).map{ charset.to_a[rand(charset.size)] }.join
	end
	def hash_pass(password)
		return Digest::MD5.hexdigest(password)
	end
end