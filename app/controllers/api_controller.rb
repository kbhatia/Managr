require ::Rails.root.join('config','lib','Facebook.rb')
require 'rubygems'
require 'aws-sdk'

class ApiController < ApplicationController

  skip_before_action :require_login, only: [:index, :get_feed, :post_status, :oauth_exchange]
  
  def index
    if session[:fb_access_token]
      redirect_to home_url
    else
      @client_id = FACEBOOK_CONFIG['client_id']
      @redirect_uri = FACEBOOK_CONFIG['redirect_uri']
    end
  end

  def home
    resp = Facebook.api_call('get', "https://graph.facebook.com/me/accounts", {
      :access_token => session[:fb_access_token]
    })
    if resp[:status][:success]
      @page_names = ActiveSupport::JSON.decode(resp[:data])
    else
      if resp[:status][:err_type] == 'OAuthException'
        reset_session
        redirect_to root_url
      else
        flash[:fb_error_get_pages] = 'Error getting pages.'
        @page_names = false
      end
    end
  end

  def get_feed
    page_id = params[:page_id] ? params[:page_id].split('&')[0] : false
    fb_req_url = params[:fb_req_url] ? params[:fb_req_url] : "https://graph.facebook.com/#{page_id}/promotable_posts?fields=picture,message,link,type"
    resp = Facebook.api_call('get', fb_req_url, {
      :access_token => session[:fb_access_token]
    })

    if resp[:status][:success]
     all_insights = build_posts_batch(ActiveSupport::JSON.decode(resp[:data]))
     if all_insights[:status][:success]
       all_data = ActiveSupport::JSON.decode(resp[:data])
       insight_body = ActiveSupport::JSON.decode(all_insights[:data].body)
       ret = {
         :data => []
       }
       all_data['data'].zip(insight_body).each do |post, insight|
         puts post
         in_data = ActiveSupport::JSON.decode(insight['body'])
         begin
           post['views'] = in_data['data'][0]['values'][0]['value']
         rescue
           post['views'] = 0
         end
         ret[:data].push(post)
       end
       ret[:paging] = all_data['paging']
       render :json => {
        :status => {
          :success => true
        },
        :data => ret
      }
     else
       render :json => {
        :status => {
          :success => true
        },
        :data => ActiveSupport::JSON.decode(resp[:data])
      }
     end
     
    else
      if resp[:status][:err_type] == 'OAuthException'
        render :json => {
          :status => {
            :success => false,
            :msg => 'Your session has expired. Please log out and back in again.'
          }
        }
      else
        render :json => {
          :status => {
            :success => false,
            :msg => 'Error getting feed.'
          }
        }
      end
    end
  end

  def post_status
    page_token = params[:page_name].split('&')[1]
    publish = params[:publish_type] == 'published' ? true : false

   if params.has_key?(:photo)
    resp = post_photo
   else
     resp = Facebook.api_call('post', "https://graph.facebook.com/me/feed?access_token=#{page_token}", {
      message: params[:message], published: publish, link: params[:link]
    })
   end
    
    if resp[:status][:success]
      redirect_to home_url     
    else
      if resp[:status][:err_type] == 'OAuthException'
        render :json => {
          :status => {
            :success => false,
            :msg => 'Your session has expired. Please log out and back in again.'
          }
        }
      else
        render :json => {
          :status => {
            :success => false,
            :msg => 'There was an error posting your status. Please try again'
          }
        }
      end
    end

  end
  
  def upload(photo)
    uploaded_io = photo.original_filename
    directory = "public/images/upload"
    path = File.join(directory, uploaded_io)
    File.open(path, "wb") { |f| f.write(photo.read) }
  end
  
  def upload_to_s3(photo)
     s3 = AWS::S3.new(
    :access_key_id => 'Your _ key _ id',
    :secret_access_key =>  'your secret access key')   
     key = File.basename(photo.original_filename)
     s3.buckets['Facebook_images'].objects[key].write(:file => photo)
     url = "https://s3.amazonaws.com/Facebook_images/#{photo.original_filename}"   
     url 
  end
  
  def post_photo
    page_id = params[:page_name].split('&')[0]
    page_token=params[:page_name].split('&')[1]
    publish = params[:publish_type] == 'published' ? true : false
   
    url = upload_to_s3(params[:photo])
    puts page_id
    puts url
    puts page_token

    resp = Facebook.api_call('post', "https://graph.facebook.com/#{page_id}/photos?access_token=#{page_token}", {
      message: params[:message], published: publish, url: url
    })
    resp
  end
  
  def get_page_likes
     page_id = params[:page_id].split('&')[0]
     resp = Facebook.api_call('get', "https://graph.facebook.com/#{page_id}/", {
      :access_token => session[:fb_access_token],
    })
     if resp[:status][:success]
      render :json => {
        :status => {
          :success => true
        },
        :data => ActiveSupport::JSON.decode(resp[:data])
      }
    else
      if resp[:status][:err_type] == 'OAuthException'
        render :json => {
          :status => {
            :success => false,
            :msg => 'Your session has expired. Please log out and back in again.'
          }
        }
      else
        render :json => {
          :status => {
            :success => false,
            :msg => 'Error getting Insight data.'
          }
        }
      end
    end
  end

  
  def get_page_insights
    page_id = params[:page_id].split('&')[0]
    resp = Facebook.api_call('get', "https://graph.facebook.com/#{page_id}/insights/page_posts_impressions_unique/", {
      :access_token => session[:fb_access_token],
    })
     if resp[:status][:success]
      render :json => {
        :status => {
          :success => true
        },
        :data => ActiveSupport::JSON.decode(resp[:data])
      }
    else
      if resp[:status][:err_type] == 'OAuthException'
        render :json => {
          :status => {
            :success => false,
            :msg => 'Your session has expired. Please log out and back in again.'
          }
        }
      else
        render :json => {
          :status => {
            :success => false,
            :msg => 'Error getting Insight data.'
          }
        }
      end
    end
  end

  def build_posts_batch(posts)
    # https://developers.facebook.com/docs/graph-api/making-multiple-requests/  
    queries = posts['data'].map { |post| {:method => 'GET', :relative_url => "#{post['id']}/insights/post_impressions_unique/lifetime"} }
    url = "https://graph.facebook.com/"
    resp = Facebook.api_call('post', url, {
      :access_token => session[:fb_access_token],
      :include_headers=> false,
      :batch =>JSON.generate(queries)
    })  
  end

  def oauth_exchange
    if params[:error]
      flash[:fb_login_error] = "There was an error logging you in. Please try again."
      redirect_to root
    else
      at_string = Facebook.api_call('get', 'https://graph.facebook.com/oauth/access_token', {
        :client_id => FACEBOOK_CONFIG['client_id'],
        :client_secret => FACEBOOK_CONFIG['client_secret'],
        :redirect_uri => FACEBOOK_CONFIG['redirect_uri'],
        :code => params[:code]
      })
      if at_string[:status][:success]
        session[:fb_access_token] = at_string[:data].split('&')[0].split('=')[1]
        redirect_to home_url
      else
        flash[:fb_login_error] = "There was an error logging you in. Please try again."
        redirect_to root_url
      end
    end
  end

  def get_next_results

  end

  def logout
    reset_session
    redirect_to root_url
  end

end
