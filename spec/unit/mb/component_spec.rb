require 'spec_helper'

describe MB::Component do
  subject do
    MB::Component.new do
      name "activemq"

      group "masters" do
        # group definition
      end
    end
  end

  describe "#groups" do
    subject do
      MB::Component.new do
        name "activemq"

        group "masters" do
          # group definition
        end

        command do
          name "start"
          description "whatever"
        end
      end
    end

    it "returns an array of Group objects" do
      subject.groups.should be_a(Array)
      subject.groups.should each be_a(MB::Group)
    end
  end

  describe "#group" do
    subject do
      MB::Component.new do
        name "activemq"

        group "masters" do
          # group definition
        end
      end
    end

    it "returns the group matching the given name" do
      subject.group("masters").name.should eql("masters")
    end
  end
end