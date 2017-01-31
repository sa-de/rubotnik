module Commands
  include Facebook::Messenger

  # helper function to send messages declaratively and directly
  def say(recipient_id, text, quick_replies = nil)
    message_options = {
    recipient: { id: recipient_id },
    message: { text: text }
    }
    if quick_replies
      message_options[:message][:quick_replies] = quick_replies
    end
    Bot.deliver(message_options, access_token: ENV['ACCESS_TOKEN'])
  end

  # Coordinates lookup
  def show_coordinates(message, id)
    if message_contains_location?(message)
      handle_user_location(message)
    else
      if !is_text_message?(message)
        say(id, "Why are you trying to fool me, human?")
      else
        handle_coordinates_lookup(message, id)
      end
    end
  end

  def handle_coordinates_lookup(message, id)
    query = encode_ascii(message.text)
    parsed_response = get_parsed_response(API_URL, query)
    message.type # let user know we're doing something
    if parsed_response
      coord = extract_coordinates(parsed_response)
      text = "Latitude: #{coord['lat']} / Longitude: #{coord['lng']}"
      say(id, text)
    else
      message.reply(text: IDIOMS[:not_found])
      show_coordinates(message, id)
    end
  end

  # Display a set of quick replies that serves as a menu
  def show_replies_menu(id, quick_replies)
    say(id, IDIOMS[:menu_greeting], quick_replies)
  end

  def message_contains_location?(message)
    if attachments = message.attachments
      attachments.first['type'] == 'location'
    else
      false
    end
  end

  # Lookup based on location data from user's device
  def lookup_location(message, sender_id)
    if message.sender == sender_id
      if message_contains_location?(message)
        handle_user_location(message)
      else
        message.reply(text: "Please try your request again and use 'Send location' button")
      end
    end
  end

  def handle_user_location(message)
    coords = message.attachments.first['payload']['coordinates']
    lat = coords['lat']
    long = coords['long']
    message.type
    # make sure there is no space between lat and lng
    parsed = get_parsed_response(REVERSE_API_URL, "#{lat},#{long}")
    address = extract_full_address(parsed)
    message.reply(text: "Coordinates of your location: Latitude #{lat}, Longitude #{long}. Looks like you're at #{address}")
  end

  # Full address lookup
  def show_full_address(message, id)
    if message_contains_location?(message)
      handle_user_location(message)
    else
      if !is_text_message?(message)
        say(id, "Why are you trying to fool me, human?")
        wait_for_any_input
      else
        handle_address_lookup(message, id)
      end
    end
  end

  def handle_address_lookup(message, id)
    query = encode_ascii(message.text)
    parsed_response = get_parsed_response(API_URL, query)
    message.type # let user know we're doing something
    if parsed_response
      full_address = extract_full_address(parsed_response)
      say(id, full_address)
    else
      message.reply(text: IDIOMS[:not_found])
      show_full_address(message, id)
    end
  end

  # Talk to API
  def get_parsed_response(url, query)
    response = HTTParty.get(url + query)
    parsed = JSON.parse(response.body)
    parsed['status'] != 'ZERO_RESULTS' ? parsed : nil
  end

  def encode_ascii(s)
    Addressable::URI.parse(s).normalize.to_s
  end

  def is_text_message?(message)
    !message.text.nil?
  end


  def extract_coordinates(parsed)
    parsed['results'].first['geometry']['location']
  end

  def extract_full_address(parsed)
    parsed['results'].first['formatted_address']
  end
end
