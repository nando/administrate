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
    first_customer = create(
      :customer,
      name: "First",
      email_subscriber: false)
    subscribed_customer = create(
      :customer,
      name: "Second",
      email_subscriber: true)
    other_customer = create(
      :customer,
      name: "Third",
      email_subscriber: false)

    visit admin_customers_path
    fill_in :search, with: query
    submit_search
    page.within(:xpath, '//table[@aria-labelledby="page-title"]') do
      expect(page).not_to have_content(first_customer.name)
      expect(page).to have_content(subscribed_customer.name)
      expect(page).not_to have_content(other_customer.name)
    end
  end

  scenario "ignores malicious scope searches", :js do
    query = "scope:destroy_all"
    customer = create(
      :customer,
      name: "FooBar destroy_all: user",
      email_subscriber: false)

    visit admin_customers_path
    fill_in :search, with: query
    submit_search

    expect(page).to have_content(customer.name)
  end

  scenario "admin searches a word into a model scope", :js do
    searching_for = "Lua"
    query = "scope:subscribed #{searching_for}"
    subscribed_unmathed = create(
      :customer,
      name: "Dan Croak",
      email_subscriber: true)
    subscribed_matched = create(
      :customer,
      name: "#{searching_for} Miaus",
      email_subscriber: true)
    unsubscribed_matched = create(
      :customer,
      name: "#{searching_for} Doe",
      email_subscriber: false)

    visit admin_customers_path
    fill_in :search, with: query
    submit_search

    page.within("table tbody", match: :first) do
      expect(page).to have_content(subscribed_matched.name)
    end

    expect(page).not_to have_content(subscribed_unmathed.name)
    expect(page).not_to have_content(unsubscribed_matched.name)
  end

  scenario "admin searches a word inside two model scopes", :js do
    searching_for = "Lua"
    query = "scope:subscribed scope:old #{searching_for}"
    subscribed_unmathed = create(
      :customer,
      name: "Dan Croak",
      email_subscriber: true)
    unsubscribed_matched = create(
      :customer,
      name: "#{searching_for} Doe",
      email_subscriber: false)
    subscribed_match_but_new = create(
      :customer,
      created_at: 1.day.ago,
      name: "#{searching_for} New",
      email_subscriber: true)
    subscribed_and_old_match = create(
      :customer,
      created_at: 5.years.ago,
      name: "#{searching_for} Miaus",
      email_subscriber: true)

    visit admin_customers_path
    fill_in :search, with: query
    submit_search

    page.within("table tbody", match: :first) do
      expect(page).to have_content(subscribed_and_old_match.name)
    end
    expect(page).not_to have_content(subscribed_unmathed.name)
    expect(page).not_to have_content(unsubscribed_matched.name)
    expect(page).not_to have_content(subscribed_match_but_new.name)
  end

  scenario "admin searches using a model scope w/ an argument", :js do
    query = "scope:name_starts_with(L)"
    match = create(
      :customer,
      name: "Lua Miaus")
    unmatch = create(
      :customer,
      name: "John Doe")

    visit admin_customers_path
    fill_in :search, with: query
    submit_search

    page.within("table tbody", match: :first) do
      expect(page).to have_content(match.name)
    end
    expect(page).not_to have_content(unmatch.name)
  end

  scenario "admin searches using a 'wildcarded' scope", :js do
    query = "name_starts_with:ZZ"
    match = create(
      :customer,
      name: "ZZTop")
    unmatch = create(
      :customer,
      name: "John Doe")

    visit admin_customers_path
    fill_in :search, with: query
    submit_search
    page.within("table tbody", match: :first) do
      expect(page).to have_content(match.name)
    end
    expect(page).not_to have_content(unmatch.name)

    # ...and the wildcarded scope doesn't have its button to be clicked.
    expect(page).not_to have_content("name_starts_with:*")
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
