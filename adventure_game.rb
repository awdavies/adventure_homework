# Andrew Davies; Yoong Kim; Homework 7 #

### Insert WARMUP code here. ###################################################

def print_indented enum
  if enum
    enum.sort.each {|x|
      puts "  #{x}"
    } if enum
  end
end

def when_detected enum, obj
  if enum and obj
    enum.each {|x|
      yield x if x.to_s == obj.to_s
    }
  else
    return nil
  end
end

### End of WARMUP code. ########################################################

class Module # An example of metaprogramming for the help system.
  private
  # A method that will set the help text for the given command.
  def set_cmd_help cmd_name, help_str
    help_var = ("help_"+cmd_name.to_s).to_sym
    define_method help_var do help_str end
  end
end

# A global state mixin.  Contains error recovery for bad player
# commands, a help system, and stubs for the basic methods any state
# needs in order to work properly in our game design.
module SystemState

  # For any unknown command entered by a player, this method will be
  # invoked to inform the player.  self is returned as the new active
  # state.
  def method_missing m, *args
    if m.to_s[0..3] === "cmd_" # Check if it's a game command.
      puts "Invalid command: please try again or use the 'help' command."

      # Since this method is called in place of a command method,
      # it must act like a command method and return a State.
      self
    else # Otherwise, it's a real missing method.
      super.method_missing m, *args
    end
  end

  set_cmd_help :help, "\t\t--   print available list of commands"

  # A global help command for a player to call at any time.  This will
  # print all available commands for the user and return self, not
  # changing the game state.
  def cmd_help
    cmd_names = self.public_methods.find_all {|m| m =~ /^cmd_/}
    cmd_help = cmd_names.map do |cmd|
      cmd_name = cmd.to_s[4..-1]
      help_method = "help_"+cmd_name
      cmd_help = ""
      cmd_help = self.send help_method if self.respond_to? help_method
      cmd_name + " " + cmd_help
    end

    puts "These are the currently available commands:"
    print_indented cmd_help
    self
  end

  set_cmd_help :quit, "\t\t--   quit the game"

  # Set the game as finished.
  def cmd_quit
    @endgame = true
    self
  end

  # Returns true iff the quit command has been called.
  def finished?
    @endgame
  end

  # When a state is finished, this method will be called to inform the
  # user of the results.  This stub will raise an exception and must
  # be overridden in any state that has a finished? method that
  # returns true.
  def print_result
    # Thank the user for dropping by.
    puts
    puts "Thanks for dropping by!"
  end
end

# A simple state that signals a finished game and has a print_result
# informing the user of a failure game conclusion.
class FailureState
  # As all good state classes must, include the SystemState module.
  include SystemState

  # Always return true to signal an end game scenario.
  def finished?
    true
  end

  # Prints a failure message for the player.
  def print_result
    puts
    puts "You failed!!!"
  end
end

# A simple state that signals a finished game and has a print_result
# informing the user of a victorious game conclusion.
class VictoryState
  # As all good state classes must, include the SystemState module.
  include SystemState

  # Always returns true to signal an end game scenario.
  def finished?
    true
  end

  # Prints a congratulatory message for the player.
  def print_result
    puts
    puts "Good job!!! You win!!!"
  end
end

# The humble ancestor for all items or enemies.
class Entity
  attr_reader :tag

  def initialize tag
    @tag = tag
  end

  def to_s
    @tag
  end
end


######### ADVENTURE GAME code here. #########

#### SystemState module extension ####
#
# Adds a method to move between rooms and change state
# accordingly.  Extend this method if creating
# new states for rooms
module SystemState
  private
  # changes the state accoring to the room.
  # Enemies are checked first as kickin ass is
  # highest priority.
  def move_to_room world, room
    if world[:rooms][room]
      if world[:rooms][room][:enemies]
        return FightState.new world, room
      elsif world[:final_room] == room
        return VictoryState.new
      else
        return RoomState.new world, room
      end
    end
  end
end

#### PlayerState module extension #####
#
# Adds the ability to check a player's inventory
# and health.
module PlayerState
  set_cmd_help :inventory, "\t--   display your inventory"

  # Checks the player's inventory and complains
  # if it's empty.
  def cmd_inventory
    puts " Inventory:"
    if @world[:inventory] and @world[:inventory].size > 0
      print_indented (@world[:inventory].map {|x|
                        if use?(x)
                          x.to_s + " *"
                        else
                          x.to_s
                        end})
    else
      puts "  You don't have anything!"
    end
    self
  end

  set_cmd_help :health, "\t--   display your current health"

  # Shows how much health the player has
  def cmd_health
    puts "Current Health: #{@world[:health]}"
    self
  end

  set_cmd_help :use, "<item>\t--   use an item (results may vary)"

  def cmd_use item_name=nil, *args
    when_detected @world[:inventory], item_name do |item|
      begin
        #include @roomsym in case the item needs to know
        #which room it's in for combat
        if use?(item) and item.use @world, @roomsym, *args
          return counter_attack if self.class == FightState
        else
          puts "You failed to use the item..."
        end
        return self

      rescue ArgumentError
        puts "You cannot use the item this way!"
        return self
      end
    end

    puts "No such item..."
    self
  end

  private

  # Apparently the methods for Entity subclasses have to be
  # checked with a string and NOT a symbol.  Tsk tsk ruby 1.8.6
  # that's NOT how 1.9 rolls
  def use? entity
    methods = entity.methods
    return (methods.include? "use" or methods.include? :use)
  end
end

# The State of the game when a player is peacefully hanging out in a
# particular room in the world.
class RoomState
  # As all good state classes must, include the SystemState module.
  include SystemState
  include PlayerState # We also want these commands

  # Given a world hash and (optionally) a key to the world[:rooms]
  # hash, this method will initialize a State in which the player is
  # in the given room and current state of the world.  If no room is
  # given, world[:start_room] is used instead.
  def initialize world, room=nil
    @world = world

    if room
      @room = world[:rooms][room]
    else
      @room = world[:rooms][world[:start_room]]
    end

    puts @room[:desc]
    puts
  end

  set_cmd_help :look, "\t\t--   look around the room for items, exits, etc."

  # Allows the player to look at the room's description, the current
  # items in the room, and the available exits to other rooms.
  def cmd_look
    puts @room[:desc]
    puts

    # Print items
    if @room[:items] and not @room[:items].empty?
      puts " Items within reach:"
      print_indented @room[:items]
    end

    # Print exits
    puts " You see the following exits:"
    print_indented(@room[:exits].map do |dir, room_key|
                     room = @world[:rooms][room_key]
                     dir.to_s + " (" + room[:name] + ")"
                   end)
    self # No change in the game's State
  end

  set_cmd_help :go, "<dir>\t--   go through the exit in the given direction"

  # Given a direction (optionally), takes the player to corresponding
  # if it exists.  If no such direction exists or no direction is
  # given, a helpful notification will display to the user.
  def cmd_go direction=nil
    if not direction
      puts "Go where???"
      self
    elsif not @room[:exits][direction.to_sym]
      puts "No such place to go! (Maybe you should look around for an exit!)"
      self
    else
      newroom = @room[:exits][direction.to_sym]
      move_to_room @world, newroom
    end
  end

  set_cmd_help :take, "<item>\t--   take the item and put it in the inventory"

  # Allow the player to take an item (with the given item_tag) from
  # the room and place it in their inventory.  If no such item with
  # the item_tag exists or no item_tag is passed, a helpful
  # notification will display to the user.
  def cmd_take item_tag=nil
    if not item_tag
      puts "Take what???"
      return self
    end

    when_detected @room[:items], item_tag do |item|
      @world[:inventory] ||= [] # To deal with nils
      @world[:inventory].push item
      @room[:items].delete item
      puts "You grabbed the " + item_tag
      return self
    end

    # No item found...
    puts "No such item..."
    self
  end
end

#### FightState class and related Entity subclasses ####

#### FightState Class ####
#
# Allows the player to choose fighting commands when getting into
# a scuffle.  The player has the option to defend (gain some health
# while allowing enemies to go through their counterattack phase), attack,
# and check to see which enemies are on the field.  Fights are turn-based,
# so when the player chooses to do a verbal command like defend or attack,
# the player's turn ends afterward and the enemies have a chance to
# counterattack.
#
# The player can also choose to run away using the escape command.
# It's based on a random percentage.
class FightState
  include SystemState
  include PlayerState

  def initialize world, room
    puts "You've been ambushed!"
    puts
    @world = world
    @room = @world[:rooms][room]
    @roomsym = room
    @attack = 0
    @defense = 0
    if @world[:inventory]
      @world[:inventory].each do |item|
        @attack += item.att
        @defense += item.def
      end
    end
    cmd_enemies

end

  set_cmd_help :attack, "\t--   select an enemy to attack"

  def cmd_attack enemy_tag=nil
    if not enemy_tag
      puts "Attack what?"
      return cmd_enemies
    else
      when_detected @room[:enemies], enemy_tag do |enemy|
        # set damage to zero so as not to add health
        dmg = netdmg(@attack, enemy.def)
        # Attack phase for user
        puts "You attacked the #{enemy} with a power of #{dmg}!"
        enemy.health -= dmg
        if enemy.health < 1
          puts "#{enemy} has been defeated!"
          @room[:enemies].delete enemy
        else
          puts "#{enemy} has #{enemy.health} health left."
        end
        # Checking if the enemies have been defeated
        if @room[:enemies].empty?
          puts "You have won this battle!"
          puts
          @room.delete(:enemies)
          # make sure to return a symbol rather than the room field
          return move_to_room @world, @roomsym
        end

        # The enemy attacking phase
        return counter_attack
      end

      puts "No such enemy..."
      self
    end
  end

  set_cmd_help :stats, "\t--   check your character's stats"

  def cmd_stats
    puts " Stats:"
    puts "  Health\t--   #{@world[:health]}"
    puts "  Attack\t--   #{@attack}"
    puts "  Defense\t--   #{@defense}"
    self
  end

  set_cmd_help :defend, "\t--   defend yourself from attacks for 1 turn"

  # Lets the player defend and gain a little health in the
  # process.
  def cmd_defend
    state = counter_attack
    if @world[:health] > 0
      puts "Catching your breath, you gained 1 health!"
      @world[:health] += 1
    end
    return state
  end

  set_cmd_help :enemies, "\t--   display the enemies in the immediate area"

  # Displays the enemies in the current room
  def cmd_enemies
    puts " Enemies:"
    print_indented @room[:enemies]
    self
  end

  set_cmd_help :escape, "\t--   attempt to run from the enemies"

  # allows the character to run to a random room
  # based on a percentage.  If the character has a defense
  # greater than the enemies' attack damage, it's a gauranteed
  # escape
  def cmd_escape
    if @room[:exits]
      room = @room[:exits][@room[:exits].keys[rand(@room[:exits].keys.size)]]
      puts "You attempt to escape..."
      enemy_att = 0.0
      @room[:enemies].each {|x| enemy_att += x.att.to_f}
      pct = (@defense.to_f/enemy_att)*100
      if rand(101) < pct
        puts "After a tough struggle, you escaped to #{@world[:rooms][room][:name]}"
        return move_to_room @world, room
      end
    end

    puts "You cannot escape!"
    return counter_attack
  end

  private

  # Keeps the damage from being below zero
  def netdmg att, df
    if df > att
      return 0
    else
      return att - df
    end
  end

  # Lets the enemies shred through the player
  # one at a time. Returns a failure state if the player
  # dies
  def counter_attack
    if @room[:enemies]
      @room[:enemies].each do |enemy|
        dmg = netdmg(enemy.att, @defense)
        @world[:health] -= dmg
        puts "The #{enemy} struck with a power of #{dmg}"
        if @world[:health] < 1
          return FailureState.new
        end
      end
      puts "Current health: #{@world[:health]}"
      self
    else
      move_to_room @world, @roomsym
    end
  end
end

#### Entity Modules ####

### Item Class ###
#
# For any Entity subclass that
# is an item
class Item < Entity
  attr_reader :att, :def
  include Comparable

  def <=> other
    @tag<=>other.tag
  end

  private
  # for those items with use methods that only really depend
  # on thwarting a room of enemies in a given room
  def usecontxt world, room, mesg, enemy
    when_detected world[:rooms][room][:enemies], enemy do |baddy|
      puts mesg
      puts
      world[:rooms][room].delete :enemies
    end
  end
end

### Enemy Class ###
#
# For any Entity subclass that
# is an Enemy
class Enemy < Item
  attr_accessor :health
end

## Test Entities for TestGame1 ##
class GoblinEnemy < Enemy
  def initialize
    @tag = "goblin"
    @health = 5
    @att = 2
    @def = 1
  end
end

class MimeEnemy < Enemy
  def initialize
    @tag = "mime"
    @health = 3
    @att = 2
    @def = 1
  end
end

class ClownHammerWeapon < Item
  def initialize
    @tag = "clownhammer"
    @att = 3
    @def = 1
  end
end

class BalloonShield < Item
  def initialize
    @tag = "balloonshield"
    @att = 1
    @def = 3
  end
end

## End of Test Entites ##

######## HHGTTG Entites ############

class Mice < Enemy
  def initialize
    @tag = "mice"
    @health = 5
    @att = 10
    @def = 50
  end
end

class Phil < Enemy
  def initialize
    @tag = "phil_the_door"
    @health = 42
    @att = 5000
    @def = 7777
  end
end

class Towel < Item
  def initialize
    @tag = "towel"
    @att = 0
    @def = 1
  end

  def use world=nil, room=nil
    if world and room
      enemy = "bugbladder_beast"
      mesg = "You placed the towel over your head, and the Ravenous
Bugbladder Beast, being so stupid, thought you disappeared, and
wandered off..."
      usecontxt world, room, mesg, enemy
    end
  end
end

class Bugbeast < Enemy
  def initialize
    @tag = "bugbladder_beast"
    @health = 10000
    @att = 10000
    @def = 10000
  end
end

class Peanuts < Item
  def initialize
    @tag = "peanuts"
    @att = 0
    @def = 0
  end

  def use world=nil, room=nil
    if world
      puts "You ate those nasty peanuts from the pub and gained 1 health."
      world[:health] += 1
      world[:inventory].delete self
      return true
    else
      return false
    end
  end
end

# Add a use method later
class KeyCard < Item
  def initialize
    @tag = "keycard"
    @att = 1
    @def = 0
  end

  def use world=nil, room=nil
    if world and room
      enemy = "phil_the_door"
      mesg = "Phil shut his face after you showed him that keycard you found
back on Traal.  Maybe one of the old employees was eaten by the Bugbladder Beast\?"
      usecontxt world, room, mesg, enemy
    end
  end
end

class Guide < Item
  def initialize
    @tag = "hitchhikers_guide"
    @att = 10
    @def = 5
  end

  def use world=nil, room=nil
    puts "There are some useful facts written in the guide:"
    print "Which of them would you like to read (1-5) ? "
    until (1..5).include?(num = gets.strip.to_i)
      puts "Don't be a stooge, pick something better!"
      print "(1-5) ? "
    end
    self.send ["one", "two", "three", "four", "five"][num - 1].to_sym
    puts
    true
  end

  private

  def one
    puts "1:"
    puts "The Ravenous Bug Bladder Beast of Traal is the most horrid
yet stupid animal in the universe.  With fangs the size of a TA workload, one
wouldn't stand a chance against one.  However, if you were to cover your
head with something towel-like, it would become confused and wander off,
as it thinks if you can't see it, it can't see you."
  end

  def two
    puts "2:"
    puts "The Joo Janta Peril Sensitive Sunglasses are great for keeping
the wearer very calm.  At the sign of anything that might cause the wearer
any distress, they go completely black.  Great for avoiding any sort of
visual torture devices."
  end

  def three
    puts "3:"
    puts "In the beginning, the universe was created.  This has made a lot
of people very angry and is widely regarded as a bad move."
  end

  def four
    puts "4:"
    puts "Mice are the smartest creatures from the backwater incestuous hole known
as Earth.  They are closely followed by dolphins, and then not-so-closely followed
by humans.  Despite their intelligence, they are very self-conscious about their size,
and they try to compensate for it by building large machines.  They are incapable of
having a sense of proportion in the universe."
  end

  def five
    puts "5:"
    puts "The Pan Galactic Gargle Blaster is the craziest drink in the universe.
Having one glass feels like having your brain smashed out of your head by a lime
wrapped around a golden brick.  They have a recipe, but in this revision of the guide,
the author became very lazy and didn't write it down.  That employee (formerly Andrew
Davies of Seattle, Washington, Earth), has since been fired, thankfully."
  end
end

# add use method here, too
class PerpVort < Item
  def initialize
    @tag = "total_perspective_vortex"
    @att = 500
    @def = 0
  end

  def use world=nil, room=nil
    if world and room
      enemy = "mice"
      mesg = "The mice gazed into the Total Perspective Vortex while you wore your super
cool Joo Janta Super Chromatic Peril Sensitive Sunglasses.  Due to their
terrible sense of proportion, and their self-consciousness about being small, they burst
into a puff of disbelief and self-loathing.  It was quite spectacular to watch."
      usecontxt world, room, mesg, enemy
    end
  end
end

class FairyCake < Item
  def initialize
    @tag = "fairy_cake"
    @att = 3
    @def = 10
  end
end

class PerpVortEn < Enemy
  def initialize
    @tag = "total_perspective_vortex"
    @health = 1
    @att = 500
    @def = 500
  end
end

class Pint < Item
  def initialize
    @tag = "pint"
    @att = 0
    @def = 0
  end

  def use world=nil, room=nil
    if world
      print "You drank a cold pint.  "
      if rand(2) == 1
        puts "It was quite unpleasant.  You gained 100 health... divided by infinity"
        true
      else
        puts "You choked on it, stumbled, and bumped your head on
some sharp corner.  You lost 0.5 health"
        world[:health] -= 0.5
        true
      end
      world[:inventory].delete self
    end
  end
  false
end

class VogonShip < Enemy
  def initialize
    @tag = "vogon_ship"
    @health = 1
    @att = 10000
    @def = 10000
  end
end

# have fun typing this in, you'll need them! hahahahahaha!
class Shades < Item
  def initialize
    @tag = "super_chromatic_peril_sensitive_sunglasses"
    @att = 0
    @def = 5
  end

  def use world=nil, room=nil
    if world and room
      enemy = "total_perspective_vortex"
      mesg =  "You put on your Joo Janta Super Chromatic Peril Sensitive Sunglasses,
and, being completely calm and oblivious to the terrible effects of the Total Perspective
Vortex, you turned it off as if you were cool as a fool in a swimming pool.

It is now sitting inert next to a peice of fairy cake."
      usecontxt world, room, mesg, enemy
    end
  end
end

######## End HHGTTG Entities ########

######## Mario Entities ###########

# SniperRifle has use function for targeting baddies
# e.g. "use M40_rifle goomba"
# This special use isn't going to work on class Peach
class SniperRifle < Item
  def initialize
    @tag = "M40_rifle"
    @att = 9
    @def = 0
  end

  def use world=nil, room=nil, *args
    if args and
        enemy = args[0] and
        enemy != "Peach" and
        room

      when_detected world[:rooms][room][:enemies], enemy do |baddy|
        puts "You shot #{baddy} in the face for 100 damage!"
        world[:rooms][room][:enemies].delete baddy
        world[:rooms][room].delete :enemies if world[:rooms][room][:enemies].empty?
        puts "#{baddy}'s not getting up after that..."
        puts "Mario seems quite the marksman."
        return true
      end
      puts "No such enemy..."
      return false
    else
      puts "You can't target that enemy!"
      false
    end
  end
end

class BaseballBat < Item
  def initialize
    @tag = "bat"
    @att = 1
    @def = 0
  end
end

class Mushroom < Item
  def initialize
    @tag = "mushroom"
    @att = 2
    @def = 2
  end
end

class Star < Item
  def initialize
    @tag = "star"
    @att = 100
    @def = 100
  end
end

class TurtleShell < Item
  def initialize
    @tag = "shell"
    @att = 5
    @def = 1
  end
end

class Koopa < Enemy
  def initialize
    @tag = "koopa"
    @health = 3
    @att = 2
    @def = 3
  end
end

class Goomba < Enemy
  def initialize
    @tag = "goomba"
    @health = 1
    @att = 1
    @def = 0
  end
end

class Bowser < Enemy
  def initialize
    @tag = "BOWSER"
    @health = 40
    @att = 10
    @def = 10
  end
end

class Peach < Enemy
  def initialize
    @tag = "Peach"
    @health = 1000
    @att = 100
    @def = 50
  end
end

####### End of Mario Entities #########

####  End of YOUR ADVENTURE GAME code. #########################################

# The first game state entered by the game.  This allows the player to
# select a game world or quit without doing anything.
class MainMenuState
  # As all good state classes must, include the SystemState module.
  include SystemState

  # The hash of available worlds for the player.  Worlds are defined
  # at the end of the file so that they don't clutter the code here.
  @@worlds = {}

  # Print a welcome message for the user and explain the menu.
  def initialize
    puts "Welcome to the 341 adventure game!"
    puts "I'm your host, the MainMenu!"
    puts
    cmd_help
  end

  set_cmd_help :play, "<world>\t--   start a new game"

  # If given a valid world name in $worlds, return the initial game
  # state (a RoomState) for that world.  Otherwise, tell the user
  # about any invalid world given and run the worlds command.
  def cmd_play world_name=nil
    return cmd_worlds if not world_name

    world = @@worlds[world_name]
    if not world
      puts "No such world: " + world_name
      cmd_worlds
    else
      # Introduce world and start in initial room
      puts "Welcome to the world of " + world[:long_name] + "!!!"
      puts "------------------------"
      puts world[:desc]
      puts
      RoomState.new(world.clone) # Copy world definition for mutation protection
    end
  end

  set_cmd_help :worlds, "\t--   list all available worlds to play"

  # Simply print out the available worlds to play without changing the
  # game state.
  def cmd_worlds
    puts "The available worlds:"
    print_indented @@worlds.keys
    self
  end
end

# The main class for playing the adventure game.  Simply has a play
# method that'll start up the interactive game REPL.
class Adventure
  def play
    state = MainMenuState.new
    until state.finished?
      print "Enter a command: "
      command = gets.split "\s"
      if not command.empty?
        cmd_name = "cmd_"+command[0]
        cmd_args = command[1..-1]
        puts
        # Send command to current state with its arguments.  Retrieve
        # next game state and save it for next command.
        # Commands will be sent any number of arguments that the
        # player enters all as strings.
        begin
          state = state.send cmd_name, *cmd_args
        rescue ArgumentError => e
          # Check for a player mistake (i.e. they gave a wrong number
          # of arguments to a command)
          if e.backtrace.first =~ /`#{cmd_name}'$/
            # Treat player mistake as an invalid command.
            state.method_missing cmd_name, *cmd_args
          else
            # Otherwise, it's a real exception and should be punted
            raise e
          end
        end
      end
    end

    # On a finished state, print the results for the player and end
    # the REPL.
    state.print_result
  end
end

# Add to the worlds available.
class MainMenuState
  @@worlds["TestGame1"] = { # This defines a world labeled "TestGame1"
    :long_name => "Test World Number 1", # A long name to describe the world
    :desc => "A simple test world with all the right stuff!", # Worlds description
    :health => 20,  # The player's starting health in this world
    :start_room => :room1, # The room to first place the player
    :final_room => :room4, # The goal room for the player to reach
    :rooms => { # A hash from room id's to their details
      :room1 => { # A room with :room1 as its id
        :name => "Central Room", # The room's name
        :desc => "This is an empty room with nothing in it.", # Room description
        :exits => { # Hash from exit id's to room id's
          :north => :room3,
          :south => :room2}},
      :room2 => {
        :name => "Armory",
        :desc => "You see a room filled with items (that are mostly out of reach)!",
        :items => [ClownHammerWeapon.new,  # An enum of items that can be picked up
          BalloonShield.new],
        :exits => {
          :north => :room1}},
      :room3 => {
        :name => "Enemy battle",
        :desc => "A deadly test room with deadly, deadly enemies.",
        :enemies => [GoblinEnemy.new,  # An enum of enemies in wait in this room
          MimeEnemy.new,
          ],
        :exits => {
          :south => :room1,
          :north => :room4}},
      :room4 => { # A simple room meant for ending the game
        :name => "Victory Room",
        :desc => "You reached the end of your journey.",
        :enemies => [MimeEnemy.new]}}}

  @@worlds["hhgttg"] = {
    :long_name => "Hitchhiker's Guide to the Galaxy",
    :desc => "Don't Panic!",
    :health => 1,
    :start_room => :house,
    :final_room => :restaurant,
    :rooms => {
      :house => {
        :name => "Arthur Dent's House",
        :desc => "A miserable house surrounded by yellow bulldozers",
        :items => [Towel.new],
        :exits => {:out => :lawn}},
      :lawn => {
        :name => "Front Lawn",
        :desc => "Lots of yellow bulldozers...",
        :exits => {
          :road => :pub,
          :in => :house}},
      :pub => {
        :name => "Local Pub",
        :desc => "You met up with your friend Ford, who has just told you that he is really
an alien from near Betelgeuse, and that the world is about to end.  He says he'll help you, though,
but he advises that you should eat some peanuts for protien and drink a pint or two for a muscle
relaxant when you get teleported to one of the Vogon shihps that's floating above currently.

These Vogons (terrible creatures), are planning to eradicate the earth in order to make way for a
hyperspace bypass, making it easier for commuters to get from point A to point B in a speedy fashion.",
        :items => [Peanuts.new, Pint.new],
        :exits => {
          :with_ford => :vogon_space_ship,
          :stay => :destruction,
          :out => :destruction,
          :think => :destruction,
          :to_bathroom => :destruction}},
      :destruction => {
        :name => "Local Pub",
        :desc => "Those yellow spaceships are getting awfully close",
        :enemies => [VogonShip.new]},
      :vogon_space_ship => {
        :name => "Inside the Vogon Space Ship",
        :desc => "You've gone with Ford into space after the world has evaporated into a whiff of hydrogen
and carbon monoxide.  Just remember, as Ford says, not to panic!

The vogon guards have also found you and are planning to escort you to the bridge",
        :exits => {:bridge => :vbridge}},
      :vbridge => {
        :name => "Vogon Bridge",
        :desc => "The captain, Prostetnic Vogon Jeltz, read you
and Ford his horrendous poetry.  Neither of you were a fan, and
are about to be kicked into space.",
        :exits => {:airlock => :space}},
      :space => {
        :name => "The Void of Space",
        :desc => "It's cold and you have about thirty seconds to live.
The Heart of Gold is tearing through space at the speed of improbability
with Zaphod Beeblebrox incompetently piloting in.",
        :exits => {
          :take_a_breath => :destruction,
          :with_zaphod => :heart_of_gold}},
      :heart_of_gold => {
        :name => "Heart of Gold",
        :desc => "Zaphod has his heads up his ass again.
Marvin's whining about being depressed.
There's a pair of Super-Chromatic Peril Sensitive Sunglasses
on the table.  You better check those out...",
        :items => [Shades.new],
        :exits => {
          :bridge => :hogbridge}},
      :hogbridge => {
        :name => "Heart of Gold Bridge",
        :desc => "The main command computer is here.  It
sees you and spits out a long reel of tape reading 'have
a nice day,' and then tells you how happy it is to compute
things for you.  It is clearly not turing complete.
A copy of the Hitchhiker's Guide to the Galaxy is sitting on
the side desk.",
        :items => [Guide.new],
        :exits => {
          :traal => :traal,
          :frogstarworldb => :frogstar,
          :magrathea => :magrathea,
          :heart_of_gold => :heart_of_gold}},
      :traal => {
        :name => "The terrible world of Traal.",
        :desc => "The terribly terrible world of Traal,
Home of the Ravenous Bugbladder Beast. Be Careful!",
        :enemies => [Bugbeast.new],
        :items => [KeyCard.new],
        :exits => {
          :back => :hogbridge}},
      :frogstar => {
        :name => "Frogstar World B",
        :desc => "The most evil place in the galaxy.
The place is, apart from the strange bird creatures in the
sky, completely empty.

It is littered with ruined cities,
and covered with an unusual amount of shoes.  It was driven
to peril by the unusual phenomenon known as \"Shoe Event Horizon.\"
Which relates the number of shoes to the amount of depression a
society has.

Tragic indeed...

This world is also said to be home to the most terrible torture device
in existence: The Total Perspective Vortex.",
        :exits => {
          :back => :hogbridge,
          :forward => :tpvortex}},
      :tpvortex => {
        :name => "Total Perspective Vortex",
        :desc => "The Total Perspective Vortex:
The most terrible torture device to exist in the entire universe,
it was built by Trin Tragula in order to keep his wife from pestering
him, by using the theory that every piece of matter in the universe is
affected by another to construct a virtual model of the universe from a
piece of fairy cake. There were no survivors... Trin Tragula showed
that in an infinite universe, the one thing sentient life cannot afford
to have is a sense of proportion.",
        :items => [PerpVort.new, FairyCake.new],
        :enemies => [PerpVortEn.new],
        :exits => {
          :back => :frogstar}},
      :magrathea => {
        :name => "The Planet Magrathea",
        :desc => "Magrathea is the richest hotspot for building planets.
You're told by the guide Slartibartfast that this is the place where Earth
was built.  The Earth was actually a giant computer built to solve the great
question to life, the universe, and everything.  So far, the great answer
has already been determined by the AI known as Deep Thought (unlike the computer
on the ship, this guy was Turing complete), and is well known to be 42.
Earth was destroyed about 2 minutes before it could solve the great question.",
        :exits => {
          :back => :hogbridge,
          :forward => :control_room}},
      :control_room => {
        :name => "Control Room",
        :desc => "The main control room overseeing planetary manufacturing.  There
are many large screens overseeing the building of a variety of planets, including, but
not limited to, planets made of Cheetos, Doritos, and other Junk food, Cheese planets,
Gold planets, and Planets entirely composed of sandy beaches (It's complicated, but it works
out in the end).

Next to you is the doorway to the \"Conference Room,\" which is guarded by a very angry door that
has a gun mounted on it.  Next to it is a sign that reads \"Phil the Door will shoot on sight, unless
you scan your keycard within five seconds\"",
        :exits => {
          :back => :magrathea,
          :forward => :mad_door}},
      :mad_door => {
        :name => "Phil the Door",
        :desc => "Phil the Door Shoots on sight",
        :enemies => [Phil.new],
        :exits => {
          :back => :control_room,
          :forward => :conference}},
      :conference => {
        :name => "Conference Room",
        :desc => "The mice (the smartest creatures on Earth, followed by dolphins and then humans), had
been plotting to take your brain since you're the only connection left to the computer that was Earth.
Luckily they didn't chop your noodle open and snatch it from you.",
        :enemies => [Mice.new],
        :exits => {:forward => :restaurant}},
      :restaurant => {
        :name => "Restaurant at the End of the Universe",
        :desc => "NONE!"}
    }
  }

  @@worlds["MarioWorld"] = {
    :long_name => "Super Mario",
    :desc => "The princess is in trouble again",
    :health => 1,
    :start_room => :room1,
    :final_room => :room7,
    :rooms => {
      :room1 => {
        :name => "The pipe",
        :desc => "Let's save Peach!",
        :items => [Mushroom.new],
        :exits => {:forward => :room2}},
      :room2 => {
        :name => "The goomba",
        :desc => "There's a goomba knocked unconscious on the ground.
By the way... Bowser's weak against sniper fire.",
        :enemies => [Goomba.new],
        :items => [BaseballBat.new, SniperRifle.new],
        :exits => {
          :forward => :room3,
          :back => :room1}},
      :room3 => {
        :name => "The koopa",
        :desc => "The koopa shudders in fear in the corner.",
        :enemies => [Koopa.new],
        :items => [TurtleShell.new],
        :exits => {
          :forward => :room4,
          :back => :room2}},
      :room4 => {
        :name => "King's Room",
        :desc => "Bowser is lying there... muahahaha!",
        :enemies => [Bowser.new],
        :exits => {
          :forward => :room5,
          :back => :room3}},
      :room5 => {
        :name => "The Star Room",
        :desc => "A room full of stars.",
        :items => [Star.new],
        :exits => {
          :forward => :room6,
          :back => :room4}},
      :room6 => {
        :name => "Peach's Chamber",
        :desc => "She's not happy!",
        :enemies => [Peach.new],
        :exits => {
          :forward => :room7,
          :back => :room5}},
      :room7 => {
        :name => "Win",
        :desc => "You win!"}}}
end

Adventure.new.play
