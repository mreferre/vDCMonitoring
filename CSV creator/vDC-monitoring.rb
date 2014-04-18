# Massimo Re Ferre'   
# www.it20.info
# Monitor a vCHS virtual data center leveraging the VM Monitoring APIs
# usage: ruby vCD-monitoring.rb <interval> <filename>
# where interval is how often you want to poll (expressed in seconds) and filename is the output CSV file you want to create
# NOTE: there is no error check for the input parameters. GET THEM RIGHT! 
 
require 'httparty'
require 'yaml'
require 'xml-fu'
require 'pp'
require 'csv'

# this is what the program accepts as input
# there is no control. Get them right (otherwise it will abort) 

interval = ARGV[0].to_i
filename = ARGV[1]


# This bypass certification checks... 
# NOT a great idea for production but ok for test / dev
# This will be handy for when this script will work with vanilla vCD setups (not just vCHS)

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE


class Monitor
	include HTTParty
	format :xml

	def initialize(file_path="config-vDCmonitoring.yml")
		raise "no file #{file_path}" unless File.exists? file_path
		configuration = YAML.load_file(file_path)	
		self.class.basic_auth configuration[:username], configuration[:password]
		self.class.base_uri configuration[:site]
		self.class.default_options[:headers] = {"Accept" => "application/*+xml;version=5.6"}
	end

	def login
		puts "Logging in ...\n\n"
		response = self.class.post('/api/sessions')
		#setting global cookie var to be used later on
		@cookie = response.headers['set-cookie']
		self.class.default_options[:headers] = {"Accept" => "application/*+xml;version=5.6", "Cookie" => @cookie}

	end




	def logout
		puts "Logging out ...\n\n"
		self.class.delete('/api/session')
	end



	def links
		response = self.class.get('/api/session')
		response['Session']['Link'].each do |link|
			puts link['href']
		end
	end


	#This method query the vDC and returns the 4 values (Memory and CPU allocated, Memory and CPU Reserved/Used)
	
	def queryvDC
		response = self.class.get("/api/admin/vdcs/query/")
		vDC = response['QueryResultRecords']['OrgVdcRecord']
		#There is no cycle here to parse all vDCs since there is always only 
		#one vDC in vCHS for every vCD Org. 
		#Trying to iterate (vDC.each) when there is only one vDC record 
		#doesn't seem to be working well. 
		printvDC(vDC)
		return vDC['cpuAllocationMhz'], vDC['memoryAllocationMB'], vDC['cpuUsedMhz'], vDC['memoryUsedMB']
	end
	
	#This method prints to video the 4 vDC values (Memory and CPU allocated, Memory and CPU Reserved/Used)

	def printvDC(vDC)
		if (vDC != nil)
			puts "CPU Allocated (MHz): 	#{vDC['cpuAllocationMhz']}"
			puts "Memory Allocated (MB): 	#{vDC['memoryAllocationMB']}"
			puts "CPU Reserved (MHz): 	#{vDC['cpuUsedMhz']}"
			puts "Memory Reserved (MB): 	#{vDC['memoryUsedMB']}"
			puts "\n"
		end
	end

	# This function calculates the total number of VMs in a vdc. 
	# note that the REST vms query returns actual VMs plus catalog VMs. 
	# We need to filter the latest out.  
			
	def numberVMs
		totalVMs = 0
		response = self.class.get("/api/vms/query/")
		vmarray = response['QueryResultRecords']['VMRecord']
		vmarray.each do |vm|
			if vm['isVAppTemplate'] == 'false' 
				totalVMs = totalVMs + 1
			end 
		end
		puts totalVMs
		return totalVMs
	end 
	
	
	
	# This function calculates the total capacity consumed for a given metric
	# This does what queryvDC does but it excracts ACTUAL usage 
	# Since ACTUAL usage isn't something that the vDC is aware of we have to 
	# iterate through all VMs (to get ACTUAL usage per VM) and adds up the metric per each VM

	def MetricTotal(metric)
		memoryconfigured = 0.0
		total = 0.0
		#This gets all the VMs
		response = self.class.get("/api/vms/query/")
		#This creates an array of VMs 
		vmarray = response['QueryResultRecords']['VMRecord']
		#This calculate the number of VMs in the virtual data center
		#For each VM we GET the current metrics and we increment the "total" 
		#variable with the value from each VM for that metric  
		vmarray.each do |vm|
				#This reads the memory configured for the VM.
				#This is needed cause the metric reports % memory usage, not actual memory usage
				memoryconfigured = vm['memoryMB'].to_f.round(1)
				#This saves the entire href for the VM
				vmhrefall = vm['href']
				#This extracts the /api/<vm id>/metrics/current from the href
				vmhref = vmhrefall[36..90]
				#This gets all info about the VM
				checkifmetricsavailable = self.class.get("#{vmhref}")
				#This turns those info in HTTParty:Response format into a string
				checkifmetricsavailabletxt = checkifmetricsavailable.to_s
				#This checks if the VM is deployed and the metrics are ready to be queried 
 				if checkifmetricsavailabletxt.include? "metrics/current"
					vmmetrics = self.class.get("#{vmhref}/metrics/current")
					#This creates an array of all metrics
					vmmetricsarray = vmmetrics['CurrentUsage']['Metric']
					#This control is needed cause newly created VMs won't have Metrics available
					#for a few seconds and if the programs runs at that point it will crash
					#This is probably no longer needed with the check above (the below didn't catch all conditions
					if (vmmetricsarray != nil)
						vmmetricsarray.each do |metricsvalue| 
						#This sums up the metric we passed to the function 							
						if metricsvalue['name'] == metric
							#If it's memory (% metric) we are summing up we need to do the math on actual usage 
							if metric == 'mem.usage.average'
								puts memoryconfigured
								puts metricsvalue['value'].to_f.round(1)
								#here we do the math to do the sum as well as calculate memory usage from % memoroy usage 
								total += memoryconfigured * metricsvalue['value'].to_f.round(1) / 100 
								else
								#If it's CPU (native metric) we are summing up we just take the value as is
								puts metricsvalue['value'].to_f.round(1)
								total += metricsvalue['value'].to_f.round(1)
							end
						end
					end
				end
			end 
		end
		puts metric, total.round(1), Time.now
		return total.round(1)
	end


end

monitor = Monitor.new()

monitor.login


loop do #this loop is infinite and will run every x seconds as specified in the input parameters

	sleep(interval) 
	
	#puts "CPU Used (MHz): 	#{monitor.MetricTotal('cpu.usage.average')}"
	#puts "Memory Used (MB): 	#{monitor.MetricTotal('mem.usage.average')}"
	
	#We save  
	#Timestamp, vDCCPUAllocated, vDCMEMAllocated, vDCCPUReserved, vDCMEMReserved, CPUTotal, MEMTotal, TotalNumberVMs
	
	timestamp = Time.now
	vDCCPUAllocated = monitor.queryvDC[0].to_f
	vDCMEMAllocated = monitor.queryvDC[1].to_f
	vDCCPUReserved = monitor.queryvDC[2].to_f
	vDCMEMReserved = monitor.queryvDC[3].to_f
	cpuTotal = monitor.MetricTotal('cpu.usagemhz.average')
	memTotal = monitor.MetricTotal('mem.usage.average')
	totalNumberVMs = monitor.numberVMs()
	
	
	
	
	
	# This appends to a CSV file the values for
	# Timestamp, vDCCPUAllocated, vDCMEMAllocated, vDCCPUReserved, vDCMEMReserved, CPUTotal, MEMTotal,
	# Each value is written in the same column position. A raw represent a run of the loop.
	# You can then consume this CSV file with Excel or any other tool to read data in a meaningful way 
	# eg Raphael Linechart - https://github.com/n0nick/raphael-linechart)
	
	CSV.open("./#{filename}", "ab") do |csv|
  	csv << [timestamp, 
  			vDCCPUAllocated, 
  			vDCMEMAllocated, 
  			vDCCPUReserved,
  			vDCMEMReserved, 
  			cpuTotal, 
  			memTotal,
  			totalNumberVMs]
	 	end

=begin
	#This appends to multiple CSV files the values for
	#Timestamp, vDCCPUAllocated, vDCMEMAllocated, vDCCPUReserved, vDCMEMReserved, CPUTotal, MEMTotal,
	#Some rendering tools may work better with a format like this (ie same value in the raw and not in a column) 
	#remove comments if you need this format instead  
	
	File.open('./timestamp.csv', 'a') { |f| f.write("'#{timestamp}', ") }
	File.open('./vDCCPUAllocated.csv', 'a') { |f| f.write("#{vDCCPUAllocated}, ") }
	File.open('./vDCMEMAllocated.csv', 'a') { |f| f.write("#{vDCMEMAllocated}, ") }
	File.open('./vDCCPUReserved.csv', 'a') { |f| f.write("#{vDCCPUReserved}, ") }
	File.open('./vDCMEMReserved.csv', 'a') { |f| f.write("#{vDCMEMReserved}, ") }
	File.open('./cpuTotal.csv', 'a') { |f| f.write("#{cpuTotal}, ") }
	File.open('./memTotal.csv', 'a') { |f| f.write("#{memTotal}, ") }
	File.open('./totalNumberVMs.csv', 'a') { |f| f.write("#{totalNumberVMs}, ") }

=end 

	end #endloop
 	
monitor.logout()

