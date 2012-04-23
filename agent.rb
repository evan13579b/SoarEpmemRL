#!/usr/bin/env ruby

require 'gruff'

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
    :unhealthy => Food.new(10, -6),
    :healthy   => Food.new(6, -1)
  }

  attr_reader :run_number, :days_lived, :history, :health, :qvalue, :history
  def initialize(checkup_frequency, exploration, epsilon, alpha, gamma, health = 100, retain=false)
    @retain_qvalues = retain
    @epsilon = epsilon
    @alpha = alpha
    @gamma = gamma
    @exploration = exploration
    @checkup_frequency = checkup_frequency
    @health_max = health
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
                        @exploration => "#{@exploration}",
                        @checkup_frequency => "#{@checkup_frequency}"}
    @graph_q.write('q-values.png')
  end
end

runs = 2

history_file = File.open("history.txt", "w")
# checkup frequency, exploration, epsilon, alpha, gamma, health, retain memory
agent = Agent.new(1, 0, 15, 0.2, 0.8, 2000, false)
runs.times do
  agent.run()
  history_file.puts agent.history.inspect
end
agent.save_graph
