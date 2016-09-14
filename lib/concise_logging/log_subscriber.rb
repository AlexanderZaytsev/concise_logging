module ConciseLogging
  class LogSubscriber < ActiveSupport::LogSubscriber
    INTERNAL_PARAMS = %w(controller action format _method only_path)

    def redirect_to(event)
      Thread.current[:logged_location] = event.payload[:location]
    end

    def process_action(event)
      payload = event.payload
      param_method = payload[:params]["_method"]
      method = param_method ? param_method.upcase : payload[:method]
      user_id = payload[:user_id]
      status, exception_details = compute_status(payload)
      path = "http://#{payload[:host]}" + payload[:path].to_s.gsub(/\?.*/, "")
      params = payload[:params].except(*INTERNAL_PARAMS)

      ip = Thread.current[:logged_ip]
      location = Thread.current[:logged_location]
      Thread.current[:logged_location] = nil

      app = payload[:view_runtime].to_i
      db = payload[:db_runtime].to_i

      message = format(
        "%{method} %{status} %{time} %{path} %{ip}",
        ip: format("%-15s", ip),
        method: format_method(format("%-6s", method)),
        status: format_status(status),
        time: format_runtime(app, db),
        path: path
      )
      message << " user_id=#{color(user_id, GREEN)}" if user_id.present?
      message << " #{params}" if params.present?
      message << " redirect_to=#{location}" if location.present?
      message << " #{color(exception_details, RED)}" if exception_details.present?
      message << " #{Time.now}"
      message << " "

      logger.warn message
    end

    def compute_status(payload)
      details = nil
      status = payload[:status]
      if status.nil? && payload[:exception].present?
        exception_class_name = payload[:exception].first
        status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)

        if payload[:exception].respond_to?(:uniq)
          details = payload[:exception].uniq.join(" ")
        end
      end
      [status, details]
    end

    def format_method(method)
      method
    end
    
    def format_runtime(app, db)
      total = app + db
      string = "#{total} = #{app}+#{db}"
      if total <= 200
        color(string, GREEN)
      elsif total <= 500
        color(string, YELLOW)
      else
        color(string, RED)
      end
    end

    def format_status(status)
      color(status, CYAN)
    end
  end
end
