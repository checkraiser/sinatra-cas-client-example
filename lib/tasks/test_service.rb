require 'savon'
@client = Savon.client(wsdl: "http://10.1.0.238:8082/HPUWebService.asmx?wsdl")		   
response = @client.call(:thong_tin_sinh_vien) do		
	message(masinhvien: '120639')
end
res_hash = response.body.to_hash
result = {}
ls = res_hash[:thong_tin_sinh_vien_response][:thong_tin_sinh_vien_result][:diffgram][:document_element];
if (ls != nil) then 	
	ls = ls[:thong_tin_sinh_vien]	
	
	puts ls[:email].strip if ls[:email].respond_to?(:strip)
	

end