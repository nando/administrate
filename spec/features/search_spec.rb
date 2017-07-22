require "rails_helper"

feature "Search" do
  scenario "admin searches for customer by email", :js do
    query = "bar@baz.com"
    perfect_match = create(:customer, email: "bar@baz.com")
    partial_match = create(:customer, email: "foobar@baz.com")
    mismatch = create(:customer, email: "other@baz.com")

    visit admin_customers_path
    fill_in :search, with: query
    submit_search

    expect(page).to have_content(perfect_match.email)
    expect(page).to have_content(partial_match.email)
    expect(page).not_to have_content(mismatch.email)
  end

  scenario "admin searches across different fields", :js do
    query = "dan"
    name_match = create(:customer, name: "Dan Croak", email: "foo@bar.com")
    email_match = create(:customer, name: "foo", email: "dan@thoughtbot.com")
    mismatch = create(:customer)

    visit admin_customers_path
    fill_in :search, with: query
    submit_search

    expect(page).to have_content(name_match.email)
    expect(page).to have_content(email_match.email)
    expect(page).not_to have_content(mismatch.email)
  end

  scenario "admin searches using a model scope", :js do
    query = "scope:subscribed"
    subscribed_customer = create(
      :customer,
      name: "Dan Croak",
      email_subscriber: true)
    other_customer = create(
      :customer,
      name: "Foo Bar",
      email_subscriber: false)

    visit admin_customers_path
    fill_in :search, with: query
    page.execute_script("$('.search').submit()")

    expect(page).to have_content(subscribed_customer.name)
    expect(page).not_to have_content(other_customer.name)
  end

  scenario "ignores malicious scope searches", :js do
    query = "scope:destroy_all"
    customer = create(
      :customer,
      name: "FooBar destroy_all: user",
      email_subscriber: false)

    visit admin_customers_path
    fill_in :search, with: query
    page.execute_script("$('.search').submit()")
    expect(page).to have_content(customer.name)
  end

  scenario "admin clears search" do
    query = "foo"
    mismatch = create(:customer, name: "someone")
    visit admin_customers_path(search: query, order: :name)

    expect(page).not_to have_content(mismatch.email)
    clear_search
    expect(page_params).to eq("order=name")
    expect(page).to have_content(mismatch.email)
  end

  def clear_search
    find(".search__clear-link").click
  end

  def page_params
    URI.parse(page.current_url).query
  end

  def submit_search
    page.execute_script("$('.search').submit()")
  end
end
