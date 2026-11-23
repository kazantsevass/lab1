ApplicationRecord.transaction do
  companies = [
    [ "MoGo", "New York" ], [ "Wirkkle", "London" ],
    [ "Artesis", "Saint-Petersburg" ], [ "BuildEmpire", "London" ]
  ].map do |name, location|
    Company.find_or_create_by!(name: name, location: location)
  end

  jobs = [
    [ "Sinatra React", "Remote", companies[0] ],
    [ "Ruby React", "Contract", companies[1] ],
    [ "React", "Remote", companies[2] ],
    [ "Node React", "Permanent", companies[0] ],
    [ "Ruby on Rails", "Remote", companies[3] ],
    [ "Node", "Permanent", companies[3] ],
    [ "Javascript CSS HTML", "Permanent", companies[3] ]
  ].map do |name, place, company|
    Job.find_or_create_by!(company: company, name: name, place: place)
  end

  geeks = [
    [ "Mike", "Sinatra React", true ], [ "Alex", "Ruby React", true ],
    [ "Martha", "Rails", false ], [ "Juri", "Java", true ],
    [ "Andrew", "PHP", false ], [ "Nina", "Node", true ],
    [ "Bob", "Front end", true ], [ "Kate", "PHP", false ],
    [ "Boris", "Full stack", true ]
  ].map do |name, stack, has_resume|
    Geek.find_or_create_by!(name: name, stack: stack) do |geek|
      geek.resume = "#{name} has experience with #{stack}." if has_resume
    end
  end

  [
    [ jobs[0], geeks[0], true, true ], [ jobs[0], geeks[1], false, false ],
    [ jobs[4], geeks[4], true, false ], [ jobs[5], geeks[7], false, false ]
  ].each do |job, geek, read, invited|
    Apply.find_or_create_by!(job: job, geek: geek) do |application|
      application.read = read
      application.invited = invited
    end
  end
end
