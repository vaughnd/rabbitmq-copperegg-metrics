require 'copperegg'
require 'socket'

CopperEgg::Api.apikey = ARGV[0]

metric_group = CopperEgg::MetricGroup.new(
  :name => "rabbitmq_queues",
  :label => "RabbitMQ queue sizes and utilization",
  :frequency => 60
)

metric_group.metrics << {"type"=>"ce_gauge", "name"=>"waiting_messages", "unit"=>"Messages"}
metric_group.metrics << {"type"=>"ce_gauge", "name"=>"used_queue_memory", "unit"=>"Byte"}

metric_group.save

# http://www.rabbitmq.com/man/rabbitmqctl.1.man.html
queues = `rabbitmqctl list_queues -p / messages memory`.split("\n")

total_waiting_messages = 0
total_used_memory = 0

queues.each_with_index do |queue,i|
  next if i == 0 or i == queues.size-1 # Skip first and last line.

  begin 
    parts = queue.split(" ")
    waiting_messages = parts[0].to_i
    used_memory = parts[1].to_i

    total_waiting_messages += waiting_messages
    total_used_memory += used_memory
  rescue => e
    puts e
    next
  end

end

source = Socket.gethostname + "-rabbitmq"

puts "#{Time.now}: M: #{total_waiting_messages}, MEM: #{total_used_memory}"
puts "Sending to CopperEgg as #{metric_group.name} (source: #{source}) ..."

metrics = {:waiting_messages => total_waiting_messages, :used_queue_memory => total_used_memory}

CopperEgg::MetricSample.save(metric_group.name, source, Time.now.to_i, metrics)

puts "Done!"