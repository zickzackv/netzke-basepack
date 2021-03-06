Feature: User grid
  In order to value
  As a role
  I want feature

@javascript
Scenario: UserGrid should not fail to open its windows 
  Given a user exists with first_name: "Carlos", last_name: "Castaneda"
  When I go to the UserGrid test page
  Then I should see "Carlos"
  And  I should see "Castaneda"
  And  I press "Add in form"
  Then I should see "Add User"
  
@javascript
Scenario: Adding a record via "Add in form"
  Given I am on the UserGrid test page
  When I press "Add in form"
  And I fill in "First name:" with "Herman"
  And I fill in "Last name:" with "Hesse"
  And I press "Ok"
  Then I should see "Herman"
  And I should see "Hesse"

@javascript
Scenario: Updating a record via "Edit in form"
  Given a user exists with first_name: "Carlos", last_name: "Castaneda"
  When I go to the UserGrid test page
  And I select first row in the grid
  And I press "Edit in form"
  And I fill in "First name:" with "Maxim"
  And I fill in "Last name:" with "Osminogov"
  And I press "Ok"
  Then I should see "Maxim"
  And I should see "Osminogov"
  And a user should not exist with first_name: "Carlos"

@javascript
Scenario: Deleting a record
  Given a user exists with first_name: "Carlos", last_name: "Castaneda"
  And a user exists with first_name: "Maxim", last_name: "Osminogov"
  When I go to the UserGrid test page
  And I select all rows in the grid
  And I press "Delete"
  And I press "Yes"
  Then a user should not exist with first_name: "Carlos"
  And a user should not exist with first_name: "Maxim"


