require "sinatra"
require "sinatra/reloader" if development? 
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def sort_lists(lists, &block)

      complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list)}

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do |todo, index|
      if todo[:completed]
        complete_todos[todo] = index
      else
        incomplete_todos[todo] = index
      end
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

get "/" do
  redirect "/lists"
end

# View all the lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if name is invalid. Return nil if name is valid.
def error_for_list_name(list_name)
  if !(1..100).cover? list_name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == list_name }
    "List name must be unique."
  end
end

# create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos:[] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Single list view
get "/lists/:id" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :list, layout: :layout
end

# Edit existing to-do list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Return an error message if todo is invalid. Return nil if todo is valid.
def error_for_todo(todo)
  if !(1..100).cover? todo.size
    "Todo must be between 1 and 100 characters."
  end
end


# Add a new todo to a list
post "/lists/:id/todos" do
  id = params[:id].to_i
  @list = session[:lists][id]
  todo = params[:todo].strip

  error = error_for_todo(todo)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo, completed: false}
    session[:success] = "The todo has been added."
    redirect "/lists/#{id}"
  end
end

# Delete a todo item
post "/lists/:id/todos/:index/destroy" do
  id = params[:id].to_i
  @list = session[:lists][id]
  todo_index = params[:index].to_i

  @list[:todos].delete_at(todo_index)
  session[:success] = "To do has been deleted."
  redirect "/lists/#{id}"
end

# Complete a todo item
post "/lists/:id/todos/:index" do
  id = params[:id].to_i
  @list = session[:lists][id]
  todo_index = params[:index].to_i
  is_completed = params[:completed] == "true"

  @list[:todos][todo_index][:completed] = is_completed
  session[:success] = "To do has been updated."
  redirect "/lists/#{id}"
end

# Complete all
post "/lists/:id/complete_all" do
  id = params[:id].to_i
  @list = session[:lists][id]

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All to dos have been marked as complete."
  redirect "/lists/#{id}"
end