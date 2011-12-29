require 'helper'

describe Pry::CommandSet do
  before do
    @set = Pry::CommandSet.new
    @ctx = Pry::CommandContext.new
  end

  it 'should call the block used for the command when it is called' do
    run = false
    @set.command 'foo' do
      run = true
    end

    @set.run_command @ctx, 'foo'
    run.should == true
  end

  it 'should pass arguments of the command to the block' do
    @set.command 'foo' do |*args|
      args.should == [1, 2, 3]
    end

    @set.run_command @ctx, 'foo', 1, 2, 3
  end

  it 'should use the first argument as self' do
    ctx = @ctx

    @set.command 'foo' do
      self.should == ctx
    end

    @set.run_command @ctx, 'foo'
  end

  it 'should raise an error when calling an undefined command' do
    @set.command('foo') {}
    lambda {
      @set.run_command @ctx, 'bar'
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to remove its own commands' do
    @set.command('foo') {}
    @set.delete 'foo'

    lambda {
      @set.run_command @ctx, 'foo'
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to remove its own commands, by listing name' do
    @set.command(/^foo1/, 'desc', :listing => 'foo') {}
    @set.delete 'foo'

    lambda {
      @set.run_command @ctx, /^foo1/
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to import some commands from other sets' do
    run = false

    other_set = Pry::CommandSet.new do
      command('foo') { run = true }
      command('bar') {}
    end

    @set.import_from(other_set, 'foo')

    @set.run_command @ctx, 'foo'
    run.should == true

    lambda {
      @set.run_command @ctx, 'bar'
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to import some commands from other sets using listing name' do
    run = false

    other_set = Pry::CommandSet.new do
      command(/^foo1/, 'desc', :listing => 'foo') { run = true }
    end

    @set.import_from(other_set, 'foo')

    @set.run_command @ctx, /^foo1/
    run.should == true
  end

  it 'should be able to import a whole set' do
    run = []

    other_set = Pry::CommandSet.new do
      command('foo') { run << true }
      command('bar') { run << true }
    end

    @set.import other_set

    @set.run_command @ctx, 'foo'
    @set.run_command @ctx, 'bar'
    run.should == [true, true]
  end

  it 'should be able to import sets at creation' do
    run = false
    @set.command('foo') { run = true }

    Pry::CommandSet.new(@set).run_command @ctx, 'foo'
    run.should == true
  end

  it 'should set the descriptions of commands' do
    @set.command('foo', 'some stuff') {}
    @set.commands['foo'].description.should == 'some stuff'
  end

  it 'should be able to alias method' do
    run = false
    @set.command('foo', 'stuff') { run = true }

    @set.alias_command 'bar', 'foo'
    @set.commands['bar'].name.should == 'bar'
    @set.commands['bar'].description.should == ''

    @set.run_command @ctx, 'bar'
    run.should == true
  end

  it "should be able to alias a method by the command's listing name" do
    run = false
    @set.command(/^foo1/, 'stuff', :listing => 'foo') { run = true }

    @set.alias_command 'bar', 'foo'
    @set.commands['bar'].name.should == 'bar'
    @set.commands['bar'].description.should == ''

    @set.run_command @ctx, 'bar'
    run.should == true
  end

  it 'should be able to change the descriptions of commands' do
    @set.command('foo', 'bar') {}
    @set.desc 'foo', 'baz'

    @set.commands['foo'].description.should == 'baz'
  end

  it 'should get the descriptions of commands' do
    @set.command('foo', 'bar') {}
    @set.desc('foo').should == 'bar'
  end

  it 'should get the descriptions of commands, by listing' do
    @set.command(/^foo1/, 'bar', :listing => 'foo') {}
    @set.desc('foo').should == 'bar'
  end

  it 'should return Pry::CommandContext::VOID_VALUE for commands by default' do
    @set.command('foo') { 3 }
    @set.run_command(@ctx, 'foo').should == Pry::CommandContext::VOID_VALUE
  end

  it 'should be able to keep return values' do
    @set.command('foo', '', :keep_retval => true) { 3 }
    @set.run_command(@ctx, 'foo').should == 3
  end

  it 'should be able to keep return values, even if return value is nil' do
    @set.command('foo', '', :keep_retval => true) { nil }
    @set.run_command(@ctx, 'foo').should == nil
  end

  it 'should be able to have its own helpers' do
    @set.command('foo') do
      should.respond_to :my_helper
    end

    @set.helpers do
      def my_helper; end
    end

    @set.run_command(@ctx, 'foo')
    Pry::CommandContext.new.should.not.respond_to :my_helper
  end

  it 'should not recreate a new helper module when helpers is called' do
    @set.command('foo') do
      should.respond_to :my_helper
      should.respond_to :my_other_helper
    end

    @set.helpers do
      def my_helper; end
    end

    @set.helpers do
      def my_other_helper; end
    end

    @set.run_command(@ctx, 'foo')
  end

  it 'should import helpers from imported sets' do
    imported_set = Pry::CommandSet.new do
      helpers do
        def imported_helper_method; end
      end
    end

    @set.import imported_set
    @set.command('foo') { should.respond_to :imported_helper_method }
    @set.run_command(@ctx, 'foo')
  end

  it 'should import helpers even if only some commands are imported' do
    imported_set = Pry::CommandSet.new do
      helpers do
        def imported_helper_method; end
      end

      command('bar') {}
    end

    @set.import_from imported_set, 'bar'
    @set.command('foo') { should.respond_to :imported_helper_method }
    @set.run_command(@ctx, 'foo')
  end

  it 'should provide a :listing for a command that defaults to its name' do
    @set.command 'foo', "" do;end
    @set.commands['foo'].options[:listing].should == 'foo'
  end

  it 'should provide a :listing for a command that differs from its name' do
    @set.command 'foo', "", :listing => 'bar' do;end
    @set.commands['foo'].options[:listing].should == 'bar'
  end

  it "should provide a 'help' command" do
    @ctx.command_set = @set
    @ctx.output = StringIO.new

    lambda {
      @set.run_command(@ctx, 'help')
    }.should.not.raise
  end

  it "should sort the output of the 'help' command" do
    @set.command 'foo', "Fooerizes" do; end
    @set.command 'goo', "Gooerizes" do; end
    @set.command 'moo', "Mooerizes" do; end
    @set.command 'boo', "Booerizes" do; end

    @ctx.command_set = @set
    @ctx.output = StringIO.new

    @set.run_command(@ctx, 'help')

    doc = @ctx.output.string

    order = [doc.index("boo"),
             doc.index("foo"),
             doc.index("goo"),
             doc.index("help"),
             doc.index("moo")]

    order.should == order.sort
  end

  describe "renaming a command" do
    it 'should be able to rename and run a command' do
      run = false
      @set.command('foo') { run = true }
      @set.rename_command('bar', 'foo')
      @set.run_command(@ctx, 'bar')
      run.should == true
    end

    it 'should accept listing name when renaming a command' do
      run = false
      @set.command('foo', "", :listing => 'love') { run = true }
      @set.rename_command('bar', 'love')
      @set.run_command(@ctx, 'bar')
      run.should == true
    end

    it 'should raise exception trying to rename non-existent command' do
      lambda { @set.rename_command('bar', 'foo') }.should.raise ArgumentError
    end

    it 'should make old command name inaccessible' do
      @set.command('foo') { }
      @set.rename_command('bar', 'foo')
      lambda { @set.run_command(@ctx, 'foo') }.should.raise Pry::NoCommandError
    end


    it 'should be able to pass in options when renaming command' do
      desc    = "hello"
      listing = "bing"
      @set.command('foo') { }
      @set.rename_command('bar', 'foo', :description => desc, :listing => listing, :keep_retval => true)
      @set.commands['bar'].description.should           == desc
      @set.commands['bar'].options[:listing].should     == listing
      @set.commands['bar'].options[:keep_retval].should == true
    end
  end

  describe "command decorators - before_command and after_command" do
    describe "before_command" do
      it 'should be called before the original command' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.before_command('foo') { foo << 2 }
        @set.run_command(@ctx, 'foo')

        foo.should == [2, 1]
      end

      it 'should be called before the original command, using listing name' do
        foo = []
        @set.command(/^foo1/, '', :listing => 'foo') { foo << 1 }
        @set.before_command('foo') { foo << 2 }
        @set.run_command(@ctx, /^foo1/)

        foo.should == [2, 1]
      end

      it 'should share the context with the original command' do
        @ctx.target = "test target string"
        before_val  = nil
        orig_val    = nil
        @set.command('foo') { orig_val = target }
        @set.before_command('foo') { before_val = target }
        @set.run_command(@ctx, 'foo')

        before_val.should == @ctx.target
        orig_val.should == @ctx.target
      end

      it 'should work when applied multiple times' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.before_command('foo') { foo << 2 }
        @set.before_command('foo') { foo << 3 }
        @set.before_command('foo') { foo << 4 }
        @set.run_command(@ctx, 'foo')

        foo.should == [4, 3, 2, 1]
      end

    end

    describe "after_command" do
      it 'should be called after the original command' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.after_command('foo') { foo << 2 }
        @set.run_command(@ctx, 'foo')

        foo.should == [1, 2]
      end

      it 'should be called after the original command, using listing name' do
        foo = []
        @set.command(/^foo1/, '', :listing => 'foo') { foo << 1 }
        @set.after_command('foo') { foo << 2 }
        @set.run_command(@ctx, /^foo1/)

        foo.should == [1, 2]
      end

      it 'should share the context with the original command' do
        @ctx.target = "test target string"
        after_val  = nil
        orig_val    = nil
        @set.command('foo') { orig_val = target }
        @set.after_command('foo') { after_val = target }
        @set.run_command(@ctx, 'foo')

        after_val.should == @ctx.target
        orig_val.should == @ctx.target
      end

      it 'should determine the return value for the command' do
        @set.command('foo', 'bar', :keep_retval => true) { 1 }
        @set.after_command('foo') { 2 }
        @set.run_command(@ctx, 'foo').should == 2
      end

      it 'should work when applied multiple times' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.after_command('foo') { foo << 2 }
        @set.after_command('foo') { foo << 3 }
        @set.after_command('foo') { foo << 4 }
        @set.run_command(@ctx, 'foo')

        foo.should == [1, 2, 3, 4]
      end
    end

    describe "before_command and after_command" do
      it 'should work when combining both before_command and after_command' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.after_command('foo') { foo << 2 }
        @set.before_command('foo') { foo << 3 }
        @set.run_command(@ctx, 'foo')

        foo.should == [3, 1, 2]
      end

    end

  end

  describe "class-based commands" do
    it 'should pass arguments to the command' do
      c = Class.new(Pry::CommandContext) do
        def call(*args)
          args.should == [1, 2, 3]
        end
      end

      @set.command 'foo', "desc", :definition => c.new

      ctx = @set.commands['foo'].block
      @set.run_command ctx, 'foo', 1, 2, 3
    end

    it 'should set unprovided arguments to nil' do
      c = Class.new(Pry::CommandContext) do
        def call(x, y, z)
          x.should == 1
          y.should == nil
          z.should == nil
        end
      end

      @set.command 'foo', "desc", :definition => c.new

      ctx = @set.commands['foo'].block
      @set.run_command ctx, 'foo', 1
    end

    it 'should clip provided arguments to expected number' do
      c = Class.new(Pry::CommandContext) do
        def call(x, y, z)
          x.should == 1
          y.should == 2
        end
      end

      @set.command 'foo', "desc", :definition => c.new

      ctx = @set.commands['foo'].block
      @set.run_command ctx, 'foo', 1, 2, 3, 4
    end

    it 'should return Pry::CommandContext::VOID by default' do
      c = Class.new(Pry::CommandContext) do
        def call
          :i_have_done_thing_i_regret
        end
      end

      @set.command 'foo', "desc", :definition => c.new

      ctx = @set.commands['foo'].block
      @set.run_command(ctx, 'foo').should == Pry::CommandContext::VOID_VALUE
    end

    it 'should return specific value when :keep_retval => true' do
      c = Class.new(Pry::CommandContext) do
        def call
          :i_have_a_dog_called_tobina
        end
      end

      @set.command 'foo', "desc", :keep_retval => true, :definition => c.new

      ctx = @set.commands['foo'].block
      @set.run_command(ctx, 'foo').should == :i_have_a_dog_called_tobina
    end

    it 'should have access to helper methods' do
      c = Class.new(Pry::CommandContext) do
        def call
          im_helping.should == "butterbum"
        end
      end

      @set.command 'foo', "desc", :definition => c.new

      @set.helpers do
        def im_helping
          "butterbum"
        end
      end

      ctx = @set.commands['foo'].block
      @set.run_command ctx, 'foo'
    end

    it 'should persist state' do
      c = Class.new(Pry::CommandContext) do
        attr_accessor :state
        def call
          @state ||= 0
          @state += 1
        end
      end

      @set.command 'foo', "desc", :definition => c.new

      ctx = @set.commands['foo'].block
      @set.run_command ctx, 'foo'
      @set.run_command ctx, 'foo'
      ctx.state.should == 2
    end

    describe "before_command" do
      it 'should be called before the original command' do
        foo = []
        c = Class.new(Pry::CommandContext) do
          define_method(:call) do
            foo << 1
          end
        end

        @set.command 'foo', "desc", :definition => c.new

        ctx = @set.commands['foo'].block
        @set.before_command('foo') { foo << 2 }
        @set.run_command(ctx, 'foo')

        foo.should == [2, 1]
      end
    end

  end
end
