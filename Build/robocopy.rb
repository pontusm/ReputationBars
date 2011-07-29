class Robocopy
	attr_accessor :source, :target, :excludeDirs, :excludeFiles
	
	include Rake::DSL
	
	def run()
		robocopy = "robocopy " \
					"\"#{@source}\" " \
					"\"#{@target}\" " \
					"/MIR " \
					"/XD #{@excludeDirs} " \
					"/XF #{@excludeFiles}"
			
		errorHandler = \
			lambda do |ok, res|
					raise "Robocopy failed with exit " \
							"code #{res.exitstatus}." \
					if res.exitstatus > 8
				end

		sh robocopy, &errorHandler 
	end
end

def robocopy(*args, &block)
	body = lambda { |*args|
		rc = Robocopy.new
		block.call(rc)
		rc.run
	}
	Rake::Task.define_task(*args, &body)
end
