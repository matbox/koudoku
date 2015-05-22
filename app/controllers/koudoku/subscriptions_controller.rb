module Koudoku
  class SubscriptionsController < ApplicationController
    before_filter :load_owner
    before_filter :show_existing_subscription, only: [:index, :new, :create], unless: :no_owner?
    before_filter :load_subscription, only: [:show, :cancel, :edit, :update]
    before_filter :load_plans, only: [:index, :edit]

    def load_plans
      @plans = ::Plan.order(:price)
    end

    def unauthorized
      render status: 401, template: "koudoku/subscriptions/unauthorized"
      false
    end

    def load_owner
      unless params[:owner_id].nil?
        if current_owner.present?

          # we need to try and look this owner up via the find method so that we're
          # taking advantage of any override of the find method that would be provided
          # by older versions of friendly_id. (support for newer versions default behavior
          # below.)
          searched_owner = current_owner.class.find(params[:owner_id]) rescue nil

          # if we couldn't find them that way, check whether there is a new version of
          # friendly_id in place that we can use to look them up by their slug.
          # in christoph's words, "why?!" in my words, "warum?!!!"
          # (we debugged this together on skype.)
          if searched_owner.nil? && current_owner.class.respond_to?(:friendly)
            searched_owner = current_owner.class.friendly.find(params[:owner_id]) rescue nil
          end

          if current_owner.try(:id) == searched_owner.try(:id)
            @owner = current_owner
          else
            return unauthorized
          end
        else
          return unauthorized
        end
      end
    end

    def no_owner?
      @owner.nil?
    end

    def load_subscription
      ownership_attribute = :"#{Koudoku.subscriptions_owned_by}_id"
      @subscription = ::Subscription.where(ownership_attribute => current_owner.id).find_by(id: params[:id])
      return @subscription.present? ? @subscription : unauthorized
    end

    # the following two methods allow us to show the pricing table before someone has an account.
    # by default these support devise, but they can be overriden to support others.
    def current_owner
      # e.g. "self.current_user"
      send "current_#{Koudoku.subscriptions_owned_by}"
    end

    def redirect_to_sign_up
      # this is a Devise default variable and thus should not change its name
      # when we change subscription owners from :user to :company
      session["user_return_to"] = new_subscription_path(plan: params[:plan])
      redirect_to new_registration_path(Koudoku.subscriptions_owned_by.to_s)
    end

    def index

      # don't bother showing the index if they've already got a subscription.
      if current_owner and current_owner.subscription.present?
        redirect_to koudoku.edit_owner_subscription_path(current_owner, current_owner.subscription)
      end

      # Load all plans.
      @plans = ::Plan.order(:display_order).all

      # Don't prep a subscription unless a user is authenticated.
      unless no_owner?
        # we should also set the owner of the subscription here.
        @subscription = ::Subscription.new({Koudoku.owner_id_sym => @owner.id})
        @subscription.subscription_owner = @owner
      end

    end

    def new
      if no_owner?

        if defined?(Devise)

          # by default these methods support devise.
          if current_owner
            redirect_to new_owner_subscription_path(current_owner, plan: params[:plan])
          else
            redirect_to_sign_up
          end

        else
          raise "This feature depends on Devise for authentication."
        end

      else
        @subscription = ::Subscription.new
        @subscription.plan = ::Plan.find(params[:plan])

        # create subscription & customer if free trial/plan w/o credit card
        if @subscription.plan.trial_period>0 || @subscription.plan.price==0
          @subscription.subscription_owner = @owner
          @subscription.coupon_code = session[:koudoku_coupon_code]
          if @subscription.save
            if @subscription.plan.price==0
              flash[:notice] = "Sie nuzten nun den kostenfreien JuraBlogs-Plan."
            else
              flash[:notice] = "Sie testen den Plan bis zum #{(Time.now.in_time_zone("Berlin") + @subscription.plan.trial_period.days).to_date.strftime('%d.%m.%Y')}."
            end
            redirect_to after_new_subscription_path
          end
        end

      end
    end

    def show_existing_subscription
      if @owner.subscription.present?
        redirect_to owner_subscription_path(@owner, @owner.subscription)
      end
    end

    def create
      params[:subscription].each do |key, value|
        (value == 'undefined' || value == '' || value == 'null') ? params[:subscription][key] = nil : ''
      end

      @subscription = ::Subscription.new(subscription_params)
      @subscription.subscription_owner = @owner
      @subscription.coupon_code = session[:koudoku_coupon_code]

      if @subscription.save
        flash[:notice] = after_new_subscription_message
        redirect_to after_new_subscription_path
      else
        flash[:alert] = 'Ihre Kreditkarte wurde abgewiesen. Bitte nutzen Sie eine andere Kreditkarte oder nehmen Sie mit Ihrem Zahlungsinstitut Kontakt auf.'
        redirect_to new_owner_subscription_path(@owner, plan: subscription_params[:plan_id])
      end
    end

    def show
    end

    def cancel
      flash[:notice] = "Sie haben Ihren Plan erfolgreich gekündigt."
      @subscription.plan_id = nil
      @subscription.save
      @subscription.destroy
      redirect_to '/my/profile'
    end

    def edit
    end

    def update
      params[:subscription].each do |key, value|
        (value == 'undefined' || value == '' || value == 'null') ? params[:subscription][key] = nil : ''
      end

      if @subscription.update_attributes(subscription_params)
        flash[:notice] = "Aktualisierung erfolgreich."
        redirect_to owner_subscription_path(@owner, @subscription)
      else
        flash[:alert] = 'Ihre Kreditkarte wurde abgewiesen. Bitte nutzen Sie eine andere Kreditkarte oder nehmen Sie mit Ihrem Zahlungsinstitut Kontakt auf.'
        redirect_to edit_owner_subscription_path(@owner, @subscription, update: 'source')
      end
    end

    private
    def subscription_params

      # If strong_parameters is around, use that.
      if defined?(ActionController::StrongParameters)
        params.require(:subscription).permit(:trial_start, :trial_end, :current_period_start, :current_period_end, :plan_id, :stripe_id, :blogs_allowed, :posts_allowed, :current_price, :credit_card_token, :card_type, :last_four, :name, :address_line1, :address_line2, :address_city, :address_zip)
      else
        # Otherwise, let's hope they're using attr_accessible to protect their models!
        params[:subscription]
      end

    end

    def after_new_subscription_path
      return super(@owner, @subscription) if defined?(super)
      owner_subscription_path(@owner, @subscription)
    end

    def after_new_subscription_message
      controller = ::ApplicationController.new
      controller.respond_to?(:new_subscription_notice_message) ?
          controller.try(:new_subscription_notice_message) :
          "Sie haben Ihren Plan erfolgreich aktualisiert."
    end
  end
end
