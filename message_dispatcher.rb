# ATTEMPT AT DSL
class Parser
  @message, @user, @matched = nil

  def self.bind_commands(message, user, &block)
    @message = message
    @user = user
    @matched = false
    class_eval(&block)
  end

  def self.bind(regex_string, to: nil, start_thread: {})
    if @message.text =~ /#{regex_string}/i
      @matched = true
      if block_given?
        yield
        return
      end
      if start_thread.empty?
        execute(to)
        @user.reset_command
      else
        say(@user, start_thread[:message], start_thread[:quick_replies])
        @user.set_command(to)
      end
    end
  end

  # TODO: TEST WITHOUT AN ARGUMENT
  def self.not_recognized
    unless @matched
      puts "not_recognized triggered" # debug
      yield
      @user.reset_command
    end
  end

  # TODO: use "send" instead of "call"?
  def self.execute(command)
    method(command).call(@message, @user)
  end

  private_class_method :bind, :execute, :not_recognized
end

class MessageDispatcher
  def self.dispatch(user, message)
    @user = user
    @message = message

    # The main switch happens here:
    # user either has a threaded command set from previous interaction
    # or we go back to top level commands
    if @user.current_command
      command = @user.current_command
      method(command).call(@message, @user)
      puts "Command #{command} is executed for user #{@user.id}" # log
    else
      # We only greet user once for the whole interaction
      # TODO: This shouldnt' be hardcoded, greeting should be implemented in the DSL
      greet_user(@user) unless @user.greeted?
      puts "User #{@user.id} does not have a command assigned yet" # log
      parse_commands
    end
  end

  # private


  # PARSE INCOMING MESSAGES HERE (TOP LEVEL ONLY) AND ASSIGN COMMANDS
  # FROM THE COMMANDS MODULE

  private_class_method def self.parse_commands # TESTING THE DSL ON SOME COMMANDS

    # NB: Will match multiple triggers in one phrase
    # TODO: Provide multiple regexps for the same binding
    # TODO: Implement greet() that takes a block and provides a one-off behaviour for greeting
    Parser.bind_commands(@message, @user) do
      # Any string will be turned into case-insensitive regex pattern.
      # You can also provide regex directly.

      # Use with 'to:' syntax to bind to a command found inside Commands
      # or associated modules.
      bind "carousel", to: :show_carousel

      # Use with block if you want to provide response behaviour
      # directly without looking for an existing command inside Commands.
      bind "screw" do
        say(@user, "Screw yourself!")
      end

      # Use with 'to:' and 'start_thread:' to point to the first command in a thread.
      # Provide message asking input for the next command in the nested hash.
      # You can also pass an array of quick replies.
      bind "location", to: :lookup_location,
                       start_thread: {
                         message: "Le me know your location",
                         quick_replies: LOCATION_PROMPT
                       }

      questionnaire_replies = UI::QuickReplies.build(["Yes", "START_QUESTIONNAIRE"],
                                                   ["No", "STOP_QUESTIONNAIRE"])

      bind 'questionnaire', to: :start_questionnaire,
                            start_thread: {
                              message: "Welcome to the sample questionnaire! Are you ready?",
                              quick_replies: questionnaire_replies
                            }

      # Falback action if none of the commands matched the input,
      # NB: Should always come last. Takes a block.
      not_recognized do
        show_replies_menu(@user, MENU_REPLIES)
      end

    end

    p @message # log incoming message details
  end
end

# OLD IMPLEMENTATION OF DISPATCH BASED ON CASES

# case @message.text
# when /coord/i, /gps/i
#   @user.set_command(:show_coordinates)
#   p "Command :show_coordinates is set for user #{@user.id}"
#   say(@user, IDIOMS[:ask_location], LOCATION_PROMPT)
# when /full ad/i
#   @user.set_command(:show_full_address)
#   p "Command :show_full_address is set for user #{@user.id}"
#   say(@user, IDIOMS[:ask_location], LOCATION_PROMPT)
# # when /location/i
# #   @user.set_command(:lookup_location)
# #   p "Command :lookup_location is set for user #{@user.id}"
# #   say(@user, 'Let me know your location:', LOCATION_PROMPT)
# # when /carousel/i
# #   show_carousel(@message, @user)
# #   @user.reset_command
# when /button template/i
#   show_button_template(@user.id)
#   @user.reset_command
# else
#   # Show a set of options if command is not understood
#   show_replies_menu(@user, MENU_REPLIES)
# end
