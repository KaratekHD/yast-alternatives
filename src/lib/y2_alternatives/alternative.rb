# Copyright (c) 2016 SUSE LLC.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require "cheetah"
require "y2_alternatives/control/set_choice_command"
require "y2_alternatives/control/automatic_mode_command"

module Y2Alternatives
  # Represents an alternative
  class Alternative
    # @return [String] name of the alternative.
    attr_reader :name
    # @return [String] Status of the alternative, it can be auto or manual.
    attr_reader :status
    # @return [String] Path of the actual choice.
    attr_reader :value
    # @return [Array<Choice>] Contains all Alternative's Choices.
    attr_reader :choices
    # Represents a Choice of an alternative.
    Choice = Struct.new(:path, :priority, :slaves)

    STATUS_COMMANDS = {
      "auto"   => Y2Alternatives::Control::AutomaticModeCommand,
      "manual" => Y2Alternatives::Control::SetChoiceCommand
    }
    STATUS_COMMANDS.default_proc = ->(_h, k) { raise "unknown status '#{k}'" }

    # Creates a new Alternative with the given parameters.
    def initialize(name, status, value, choices)
      @name = name
      @status = status
      @value = value
      @choices = choices
      @modified = false
    end

    # @return [Array<String>] an array with the names of the alternatives.
    def self.all_names
      raw_data = Cheetah.run("update-alternatives", "--get-selections", stdout: :capture).lines
      raw_data.map { |string| string.split.first }
    end

    # @return [Array<Alternative>] an array with all alternatives.
    def self.all
      all_names.map { |name| load(name) }
    end

    # @return [Alternative] an alternative with the given name.
    # @param name [String] The name of the alternative to be loaded.
    def self.load(name)
      raw_data = Cheetah.run("update-alternatives", "--query", name, stdout: :capture).lines
      return EmptyAlternative.new(name) unless raw_data.include?("\n")
      alternative = parse_to_map(raw_data.slice(0..raw_data.find_index("\n")))
      choices = raw_data.slice(raw_data.find_index("\n") + 1..raw_data.length)
      new(
        alternative["Name"],
        alternative["Status"],
        alternative["Value"],
        load_choices_from(choices)
      )
    end

    def self.parse_to_map(alternative_data)
      alternative = {}
      alternative_data.each do |line|
        key, value = line.split(":", 2)
        alternative[key.strip] = value.strip if !value.nil?
      end
      alternative
    end

    def self.load_choices_from(data)
      data.slice_before(/\AAlternative:/).map { |choice| load_choice(choice) }
    end

    def self.load_choice(data)
      map = to_map(data)
      Choice.new(map[:path], map[:priority], map[:slaves])
    end

    def self.to_map(choice_data)
      path, priority, *slaves = choice_data
      {
        path:     path.split.last,
        priority: priority.split.last,
        slaves:   parse_slaves(slaves)
      }
    end

    def self.parse_slaves(slaves_data)
      slaves_data.delete("\n")
      slaves_data.delete("Slaves:\n")
      slaves_data.map(&:lstrip).join
    end

    def empty?
      false
    end

    def choose!(new_choice_path)
      if !choices.map(&:path).include?(new_choice_path)
        raise "The alternative doesn't have any choice with path '#{new_choice_path}'"
      end
      @value = new_choice_path
      @status = "manual"
      @modified = true
    end

    def automatic_mode!
      @status = "auto"
      @value = choices.sort_by { |choice| choice.priority.to_i }.last.path
      @modified = true
    end

    def save
      return unless @modified
      STATUS_COMMANDS[@status].execute(self) if Process::UID.rid == 0
    end

    private_class_method :all_names, :load_choices_from, :parse_to_map
    private_class_method :load_choice, :to_map, :parse_slaves
  end
  # Represents an alternative without any choice
  class EmptyAlternative < Alternative
    def initialize(name)
      super(name, "", "", [])
    end

    def empty?
      true
    end
  end
end
