require File.dirname(__FILE__) + '/../test_helper'

class CodeReviewControllerTest < ActionController::TestCase
  fixtures :code_reviews, :projects, :users, :repositories, :changesets, :changes, :members, :roles
  def setup
    @controller = CodeReviewController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @request.env["HTTP_REFERER"] = '/'
    enabled_module = EnabledModule.new
    enabled_module.project_id = 1
    enabled_module.name = 'code_review'
    enabled_module.save

    User.current = nil
    roles = Role.find(:all)
    roles.each {|role|
      role.permissions << :view_code_review
      role.save
    }
  end

  def test_index
    @request.session[:user_id] = 1
    get :index, :id => 1
    assert_response :success
  end

  def test_index_show_closed
    @request.session[:user_id] = 1
    get :index, :id => 1, :show_closed => true
    assert_response :success
  end

  def test_new
    @request.session[:user_id] = 1
    get :new, :id => 1
    assert_response :success
    assert_template '_new_form'

    post :new, :id => 1
    assert_response :success
    assert_template '_new_form'

    count = CodeReview.find(:all).length
    post :new, :id => 1, :review => {:line => 1, :change_id => 1, :comment => 'aaa'}
    assert_response :success
    assert_template '_add_success'
    assert_equal(count + 1, CodeReview.find(:all).length)
  end

  def test_show
    @request.session[:user_id] = 1
    get :show, :id => 1, :review_id => 1
    #assert_response :success
    #assert_template '_show'
  end

  def test_destroy
    count = CodeReview.find(:all).length
    @request.session[:user_id] = 1
    get :destroy, :id => 1, :review_id => 4
    assert_response :success
    assert_equal(count - 1, CodeReview.find(:all).length)
    
  end
end