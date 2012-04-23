#!/usr/bin/env ruby

require 'optparse'
require 'gruff'
require 'yaml'

class Food
  attr_reader :score, :health
  def initialize(score, health)
    @score = score
    @health = health
  end
end

class QValues
  attr_reader :Q
  def initialize(alpha = 0.5, gamma = 0.5)
    @alpha = alpha
    @gamma = gamma
    @Q = Hash.new(0)
  end

  def update(action, reward)
    max_action, max_value = @Q.max_by { |k,v| v }
    @Q[action] = @Q[action]*(1-@alpha) + @alpha*(reward + @gamma*max_value)
  end

  def update_dead(action, reward)
    @Q[action] = @Q[action]*(1-@alpha) + @alpha*(reward)
  end

  def [](key)
    @Q[key]
  end

  def []=(key,value)
    @Q[key] = value
  end

  def max_by(&block)
    @Q.max_by(&block)
  end
end

class Agent

  WELLS = {
    :unhealthy => Food.new(10, -5),
    :healthy   => Food.new(6, 0)
  }

  attr_reader :run_number, :days_lived, :history, :health, :qvalue, :history

  def initialize(options)
    @options = options # maintain for "thinking"

    @retain_qvalues = options[:retain]
    @epsilon = options[:epsilon]
    @alpha = options[:alpha]
    @gamma = options[:gamma]
    @exploration = options[:exploration]
    @checkup_frequency = options[:checkup]
    @thinking_frequency = options[:think]
    @health_max = options[:health]

    @history_file = options[:history]
    @graph_file = options[:graph]

    @run_number = 0

    graph_setup
  end

  def graph_setup
    @graph_q = Gruff::Line.new
    @graph_q.theme_rails_keynote
    @graph_q.hide_dots = true
    colors = @graph_q.colors
    colors << '#daaea9'
    colors << '#daaeda'
    @graph_q.colors = colors
    @graph_q.title = "Q-Values"
  end

  def reset()
    @run_number += 1
    @health = @known_health = @health_max
    @days_lived = 0
    @history = []

    if !@retain_qvalues or @run_number == 1
      @qvalue = QValues.new(@alpha, @gamma)
      WELLS.keys.each do |key|
        @qvalue[key] = 0
      end
    end

    @graph_data = Hash.new { |h, k| h[k] = [] }
  end

  def run()
    reset

    until @health <= 0
      live_day
      doctors_checkup if checkup_time
    end

    assess_lifespan
    add_to_graph

    @history_file.puts @history.inspect unless @history_file.nil?
  end

  def checkup_time
    @days_lived % @checkup_frequency == 0 and @days_lived > 0
  end

  def live_day()
    well = pick_food
    eat(well)
    @days_lived += 1
  end

  # TODO: Add block to this to allow custom definition of food choices
  # Can use it for simulating experiences
  def pick_food()
    @rng ||= Random.new
    r = @rng.rand(0..100)

    # NOTE: N% of the time pick randomly (after exploration)
    if r < @epsilon or @days_lived < @exploration
      WELLS.keys.sample
    else
      @qvalue.max_by { |k, v| v }[0]
    end
  end

  def eat(well)
    @history << well
    food = WELLS[well]
    update_score(well, food)
    update_health(well, food)
  end

  def update_score(well, food)
    @qvalue.update(well, food.score) unless checkup_time
    update_graph_data
  end

  def update_health(well, food)
    @health += food.health
  end

  def doctors_checkup
    difference = @health - @known_health
    @known_health = @health

    food = WELLS[@history.last]
    @qvalue.update(@history.last, food.score + difference)
    puts "Run ##{@run_number} Difference: #{difference} (#{food.score + difference}) - #{@history.last} (#{@qvalue[@history.last]})"
    #update_graph_data
  end

  def assess_lifespan
    @qvalue.update_dead(@history.last, -100)
    #update_graph_data
  end

  def update_graph_data
    @graph_data[:unhealthy] << @qvalue[:unhealthy]
    @graph_data[:healthy] << @qvalue[:healthy]
  end

  def add_to_graph
    @graph_max ||= @days_lived
    @graph_max = [@graph_max, @days_lived].max
    @graph_q.data("Unhealthy (#{@run_number})", @graph_data[:unhealthy])
    @graph_q.data("Healthy (#{@run_number})", @graph_data[:healthy])
  end

  def save_graph
    @graph_q.labels = { 0 => '0',
                        @graph_max-1 => "#{@graph_max-1}",
                        @exploration => "Explore: #{@exploration}",
                        @checkup_frequency => "Checkup: #{@checkup_frequency}"}
    @graph_q.write(@graph_file)
  end

  # TODO: add food settings
  def to_yaml
    OPTIONS.merge(WELLS).to_yaml
  end
end

OPTIONS = {
  ## Batch config file
  :config => nil,

  ## Agent settings
  :checkup => 10,
  :think => 10,
  :exploration => 50,
  :epsilon => 15,
  :alpha => 0.2,
  :gamma => 0.8,
  :health => 100,
  :retain => false,
  :history => nil,
  :graph => "q-values.png",

  ## Script settings
  :runs => 1,
  :save => nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("--config [FILE]", "Configuration file for batched experiments") do |f|
    OPTIONS[:config] = f
  end

  opts.on("-c", "--checkup [NUM]", Integer, "Checkup frequency",
          "   Default: #{OPTIONS[:checkup]}") do |i|
    OPTIONS[:checkup] = i
  end

  opts.on("-t", "--think [NUM]", Integer, "Thinking frequency (in number of checkups)",
          "   Default: #{OPTIONS[:think]}") do |i|
    OPTIONS[:think] = i
  end

  opts.on("-e", "--exploration [NUM]", Integer, "Number of exploration stage choices",
          "   Default: #{OPTIONS[:exploration]}") do |i|
    OPTIONS[:exploration] = i
  end

  opts.on("-p", "--epsilon [NUM]", Integer, "Greedy epsilon value (integer [15 = 15%])",
          "   Default: #{OPTIONS[:epsilon]}") do |i|
    OPTIONS[:epsilon] = i
  end

  opts.on("-a", "--alpha [FLOAT]", Float, "Alpha value for reinforcement learning",
          "   Default: #{OPTIONS[:alpha]}") do |f|
    OPTIONS[:alpha] = f
  end

  opts.on("-g", "--gamma [FLOAT]", Float, "Gamma value for reinforcement learning",
          "   Default: #{OPTIONS[:gamma]}") do |f|
    OPTIONS[:gamma] = f
  end

  opts.on("-h", "--health [NUM]", Integer, "Health value for the agent",
          "   Default: #{OPTIONS[:health]}") do |i|
    OPTIONS[:health] = i
  end

  opts.on("-r", "--retain", "Retain Q-Values between runs", "   Default: #{OPTIONS[:retain]}") do
    OPTIONS[:retain] = true
  end

  opts.on("-y", "--history [FILE]", "History log file. If none supplied, will not log") do |f|
    OPTIONS[:history] = File.open(f, "w")
  end

  opts.on("-q", "--graph [FILE]", "Q-learning graph output file", "   Default: #{OPTIONS[:graph]}") do |f|
    OPTIONS[:graph] = f
  end

  opts.on("-u", "--runs [NUM]", Integer, "Number of runs for an agent",
          "   Default: #{OPTIONS[:runs]}") do |i|
    OPTIONS[:runs] = i
  end

  opts.on("--save [FILE]", "Save options configuration to file. If none supplied, will not save") do |f|
    $save = File.open(f, "w")
  end
end.parse!

agent = Agent.new(OPTIONS)
OPTIONS[:runs].times do
  agent.run()
end
agent.save_graph

unless $save.nil?
  $save.write agent.to_yaml
  $save.close
end
