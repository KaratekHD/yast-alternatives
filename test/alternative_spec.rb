require_relative "spec_helper.rb"
require "update-alternatives/model/alternative"

describe UpdateAlternatives::Alternative do

  describe ".load" do
    subject(:loaded_alternative) { UpdateAlternatives::Alternative.load("pip") }

    it "returns an Alternative object" do
      alternatives_pip_stub
      expect(loaded_alternative).to be_an UpdateAlternatives::Alternative
    end

    it "initializes the name, status and value" do
      alternatives_pip_stub
      expect(loaded_alternative).to have_attributes(
        name: "pip", status: "auto", value: "/usr/bin/pip3.4"
      )
    end

    it "initializes choices as an array of Choice objects" do
      alternatives_pip_with_two_choices_stub
      expect(loaded_alternative.choices).to be_an Array
      expect(loaded_alternative.choices).to all(be_a(UpdateAlternatives::Alternative::Choice))
    end

    it "initializes the path and priority for every choice" do
      alternatives_pip_with_two_choices_stub
      choice_one = UpdateAlternatives::Alternative::Choice.new("/usr/bin/pip2.7", "20", "")
      choice_two = UpdateAlternatives::Alternative::Choice.new("/usr/bin/pip3.4", "30", "")
      expected_choices = [choice_one, choice_two]
      expect(loaded_alternative).to have_attributes(
        choices: expected_choices
      )
    end

    context "if there are a choice without slaves" do
      it "initializes his slaves attribute to the empty string" do
        alternatives_pip_with_two_choices_stub
        expect(loaded_alternative.choices).to all(have_attributes(slaves: ""))
      end
    end

    context "if there is an alternative without choices" do
      it "returns an EmptyAlternative instance" do
        alternative_without_choices_stub
        expect(loaded_alternative).to be_an UpdateAlternatives::EmptyAlternative
        expect(loaded_alternative.empty?).to eq true
      end
    end
  end

  describe ".all" do
    subject(:all_alternatives) { UpdateAlternatives::Alternative.all }

    it "returns an array of Alternative objects" do
      alternatives_pip_with_two_choices_stub
      expect(all_alternatives).to be_an Array
      expect(all_alternatives).to all(be_an(UpdateAlternatives::Alternative))
    end

    context "if there are no alternatives in the system" do
      it "returns an empty array" do
        zero_alternatives_stub
        expect(all_alternatives.length).to eq 0
      end
    end

    context "if there are alternatives in the system" do
      it "returns an array with one Alternative object per known alternative" do
        some_alternatives_stub
        expect(all_alternatives.map(&:name)).to eq ["pip", "rake", "rubocop.ruby2.1"]
        expect(all_alternatives.length).to eq 3
      end
    end

    context "if there are alternatives without choices" do
      it "returns an array of Alternatives including the alternatives without choices" do
        some_alternatives_some_without_choices_stub
        expect(all_alternatives).to all(be_an(UpdateAlternatives::Alternative))
        expect(all_alternatives.length).to eq 4
        expect(all_alternatives.map(&:name)).to eq ["rake", "pip", "editor", "rubocop.ruby2.1"]
        expect(all_alternatives.map(&:empty?)).to eq [false, true, true, false]
      end
    end
  end

  describe "#choice" do
    subject(:alternative) do
      UpdateAlternatives::Alternative.new(
        "editor",
        "auto",
        "/usr/bin/vim",
        [
          UpdateAlternatives::Alternative::Choice.new("/usr/bin/nano", "20", ""),
          UpdateAlternatives::Alternative::Choice.new("/usr/bin/vim", "30", "")
        ]
      )
    end

    it "changes the alternative's actual choice" do
      alternative.choice("/usr/bin/nano")
      expect(alternative.value).to eq "/usr/bin/nano"
    end

    it "changes the status to 'manual'" do
      alternative.choice("/usr/bin/nano")
      expect(alternative.status).to eq "manual"
    end

    context "if the given choice path doesn't correspond to any of the alternative's choices" do
      it "do not changes the alternative's actual choice" do
        alternative.choice("/usr/bin/not-exists")
        expect(alternative.value).to eq "/usr/bin/vim"
      end

      it "do not changes the status" do
        alternative.choice("/usr/bin/not-exists")
        expect(alternative.status).to eq "auto"
      end
    end
  end

  describe "#automatic_mode" do
    subject(:alternative) do
      UpdateAlternatives::Alternative.new(
        "editor",
        "manual",
        "/usr/bin/nano",
        [
          UpdateAlternatives::Alternative::Choice.new("/usr/bin/nano", "20", ""),
          UpdateAlternatives::Alternative::Choice.new("/usr/bin/emacs", "40", ""),
          UpdateAlternatives::Alternative::Choice.new("/usr/bin/vim", "30", "")
        ]
      )
    end

    it "changes the status to 'auto'" do
      alternative.automatic_mode
      expect(alternative.status).to eq "auto"
    end

    it "changes the actual choice for the choice with highest priority" do
      alternative.automatic_mode
      expect(alternative.value).to eq "/usr/bin/emacs"
    end
  end
end
