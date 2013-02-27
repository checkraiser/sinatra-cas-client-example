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
				return {:code => -1, :msg => 'Account expired, please login'} # expired
			end
			user = activate_token.user
			if user == nil then return {:code => 0, :msg => 'Non exist user, please register'} end
			if user.status == 0  then 
				user.status = 1 
				activate_token.token = Time.now.to_s
				activate_token.status = 1				
				if user.save and activate_token.save then return {:code => 1, :msg => 'Account activated, please login'} end
			else
				return {:code => 2, :msg => 'Account already activated, please login'}
			end
		end
		return {:code => -2, :msg => 'Unknown error'}
	end
	def reconfirm(email)
		begin
			email = email.strip unless email.blank?
			user = get_user(email)
			return {:code => -1, :msg => 'Nil user'} if user == nil 
			return {:code => 2, :msg => 'Activated'} if user.status == 1
			register_confirm = Activation.new(:token => SecureRandom.hex, :created_at => Time.now, :description => 'Register reconfirmation', :status => 0)			 
			register_confirm.user = user
			if user.save and register_confirm.save then 
				sm = SendEmail.new({:to => email, :token => register_confirm.token, :reason => 'register'})
				sm.async.perform
				return {:code => 1, :msg => 'OK'}
			end
		rescue
			return {:code => -2, :msg => 'Unknown error'}
		end
	end	

	def resetpassword(email)
		begin
			email = email.strip unless email.blank?
			user = get_user(email)

			newpass = generate_password(8)
			user.password = hash_pass(newpass)
			if  user.save					
				sm = SendEmail.new({:to => email, :token => newpass, :reason => 'reset'})
	  			sm.async.perform
	  			return {:code => 1, :msg => 'Email sent to your email account, please check your inbox.'}
			else
				return {:code => -1, :msg => 'Khong ton tai thanh vien, vui long thu lai'}
			end
		rescue
			return {:code => -2, :msg => 'Unknown error'}
		end
	end
	def changeprofile(email, xprofile)
		begin			
			user = get_user(email)
			return {:code => -1, :msg => 'Nil User'} if user == nil
			profile = Profile.first(:user_id => user.id)
			return {:code => -1, :msg => 'Nil Profile'} if profile == nil			
			profile.attributes = {:hovaten => (xprofile[:hovaten] if xprofile.has_key?(:hovaten)),
				:gioitinh => (xprofile[:gioitinh] if xprofile.has_key?(:gioitinh)),
				:ngaysinh => (xprofile[:ngaysinh] if xprofile.has_key?(:ngaysinh)),
				:diachi => (xprofile[:diachi] if xprofile.has_key?(:diachi)),
				:noicongtac => (xprofile[:noicongtac] if xprofile.has_key?(:noicongtac)),
				:email => (xprofile[:email] if xprofile.has_key?(:email)),
				:dienthoai => (xprofile[:dienthoai] if xprofile.has_key?(:dienthoai))}
			if profile.save				
				return {:code => 1, :msg => 'Save Profile OK'}
			end
		rescue
			return {:code => -2, :msg => 'Unknown error'}
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


			user = User.new(:email => email, :password => password, :status => 0,  :created_at => Time.now)
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
				:dienthoai => (xprofile[:dienthoai] if xprofile.has_key?(:dienthoai))}
		  	end
		  
			register_confirm = Activation.new(:token => SecureRandom.hex, :created_at => Time.now, :description => 'Register confirmation', :status => 0)			 
			register_confirm.user = user
		  
		  
		    if user.save and register_confirm.save and profile.save and register_confirm.save		
			  	#Resque.enqueue(SendEmail, email, register_confirm.token, 'register')
			  	sm = SendEmail.new({:to => email, :token => register_confirm.token, :reason => 'register'})
			  	sm.async.perform
			  	#sendmail(user.email, register_confirm.token, :registermail)
			    #session[:user] = user.email
			    return {:code => 1, :msg => 'OK'}
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