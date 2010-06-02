
require 'active_support'

conf_defaults = {
  :maximum_unused_login_ticket_lifetime => 5.minutes,
  :maximum_unused_service_ticket_lifetime => 5.minutes, # CAS Protocol Spec, sec. 3.2.1 (recommended expiry time)
  :maximum_session_lifetime => 1.month, # all tickets are deleted after this period of time
  :log => {:file => 'casserver.log', :level => 'DEBUG'},
  :uri_path => "/"
}

if $CONF
  $CONF.merge_defaults(conf_defaults)
else
  unless $APP_NAME && $APP_ROOT
    raise "Can't load the RubyCAS-Server configuration because $APP_NAME and/or $APP_ROOT are not defined."
  end

  require 'picnic/conf'
  $CONF = Picnic::Conf.new(conf_defaults)
  local_config_path = File.join($APP_ROOT, 'config.yml')
  $CONF.load_from_file($APP_NAME, $APP_ROOT, File.exist?(local_config_path) ? local_config_path : nil)
end

$AUTH = []

unless $CONF[:authenticator]
  err =  "
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    You have not yet defined an authenticator for your CAS server!
    Please consult the documentation and make the necessary changes to
    your config file.

  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  "
  raise Picnic::Conf::Error, err
end

begin
  # attempt to instantiate the authenticator
  $CONF[:authenticator] = [$CONF[:authenticator]] unless $CONF[:authenticator].instance_of? Array
  $CONF[:authenticator].each { |authenticator| $AUTH << authenticator[:class].constantize}
rescue NameError
  if $CONF[:authenticator].instance_of? Array
    $CONF[:authenticator].each do |authenticator|
      if !authenticator[:source].nil?
        # config.yml explicitly names source file
        require authenticator[:source]
      else
        # the authenticator class hasn't yet been loaded, so lets try to load it from the casserver/authenticators directory
        auth_rb = authenticator[:class].underscore.gsub('cas_server/', '')
        require 'casserver/'+auth_rb
      end
      $AUTH << authenticator[:class].constantize
    end
  else
    if $CONF[:authenticator][:source]
      # config.yml explicitly names source file
      require $CONF[:authenticator][:source]
    else
      # the authenticator class hasn't yet been loaded, so lets try to load it from the casserver/authenticators directory
      auth_rb = $CONF[:authenticator][:class].underscore.gsub('cas_server/', '')
      require 'casserver/'+auth_rb
    end

    $AUTH << $CONF[:authenticator][:class].constantize
    $CONF[:authenticator] = [$CONF[:authenticator]]
  end
end

$CONF[:static] = {
  :urls => "/themes",
  :root  => "#{$APP_ROOT}/public"
}

