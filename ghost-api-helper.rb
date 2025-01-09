require 'awesome_print'
require 'base64'
require 'httparty'
require 'json'
require 'jwt'
require 'time'

class GhostAdmin
  include HTTParty
  format :json

  PRESERVED_EMAIL = 'jonathan.pares@gmail.com'

  def initialize(url, api_key)
    @base_url = "#{url}/ghost/api/admin"
    @headers = {
      'Authorization' => "Ghost #{generate_token(api_key)}",
      'Content-Type' => 'application/json'
    }
  end

  def get_members
    response = self.class.get(
      "#{@base_url}/members/?limit=100&page=1",
      headers: @headers
    )

    handle_response(response)['members']
  end

  def delete_member(member_id, email)
    response = self.class.delete(
      "#{@base_url}/admin/members/#{member_id}",
      headers: @headers
    )

    if response.success?
      puts "Member deleted: #{email}"
    else
      puts "Error deleting #{email}: #{response.code}"
    end
  rescue => e
    puts "Error deleting #{email}: #{e.message}"
  end

  def cleanup_members
    members = get_members
    members_to_delete = members.reject { |member| member['email'].downcase == PRESERVED_EMAIL.downcase }

    puts "Found #{members_to_delete.length} members to delete"

    members_to_delete.each do |member|
      puts "\tDeleting #{member['email']}"
      delete_member(member['id'], member['email'])
    end

    puts "Cleanup completed"
  end

  def get_posts
    response = self.class.get(
      "#{@base_url}/posts/?limit=100&page=1&fields=id,title,url,status,updated_at",
      headers: @headers
    )

    handle_response(response)['posts']
  end

  def get_post(post_id)
    response = self.class.get(
      "#{@base_url}/posts/#{post_id}?fields=id,title,url,status,updated_at",
      headers: @headers
    )

    handle_response(response)['posts'][0]
  end

  def copy_post(post_id)
    response = self.class.post(
      "#{@base_url}/posts/#{post_id}/copy",
      headers: @headers
    )

    handle_response(response)['posts'][0]
  end

  def update_post(post_id, updated_data)
    response = self.class.put(
      "#{@base_url}/posts/#{post_id}/",
      headers: @headers,
      body: { posts: [updated_data] }.to_json
    )

    handle_response(response)['posts'][0]
  end

  private

  def generate_token(api_key)
    # Split the key into ID and SECRET
    id, secret = api_key.split(':')

    # Prepare header and payload
    iat = Time.now.to_i

    header = {alg: 'HS256', typ: 'JWT', kid: id}

    payload = {
      iat: iat,
      exp: iat + 5 * 60,
      aud: '/admin/'
    }

    # Create the token (including decoding secret)
    JWT.encode(payload, [secret].pack('H*'), 'HS256', header)
  end

  def handle_response(response)
    return response.parsed_response if response.success?
    raise "API Error: #{response.code} - #{response.parsed_response['errors']&.first&.dig('message')}"
  end
end

# Usage
ADMIN_URL = ENV['ADMIN_URL']
ADMIN_KEY = ENV['ADMIN_KEY']

begin
  ghost = GhostAdmin.new(ADMIN_URL, ADMIN_KEY)

  post_id = 'xxxxxxxxxxxxxxxxxxxxxxxx'

  ap ghost.copy_post(post_id)
rescue => e
  puts "Fatal error: #{e.message}"
end
