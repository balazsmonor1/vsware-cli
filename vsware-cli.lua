-- Dependencies
local json = require("json")
local wrap = require("easywrap")

-- Get subdomain
local subdomain = wrap.get_input("VSWare Subdomain: ")
local api = "https://"..subdomain..".vsware.ie"

local apiends = {
  login = api.."/tokenapiV2/login",              -- POST
  tenant = api.."/control/tenant",               -- GET
  learners = api.."/control/household/learners", -- GET
  parental = api.."/control/parental/",          -- GET
  print_tt = api.."/control/timetable/print"     -- POST
}

-- Get Authentication
print("Please enter your VSWare login details.")
local user = wrap.get_input("username: ")
local pass = wrap.get_input("password: ")


local auth_req = wrap.http_request({
    Url = apiends.login,
    Method = "POST",
    Headers = {
      {"Content-Type","application/json, text/plain, */*"},
      {"User-Agent","Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.134 Safari/537.36"}
    },
    Body = json.encode({
        username = user,
        password = pass,
        source = "web"
    }) 
})
local found_auth = false
local token
print("Getting auth token..")
for i,v in pairs(auth_req.Cookies) do
  if wrap.starts(v,"Authorization=") then
    local items = wrap.split(v,'"')
    token = items[2]
    found_auth = true
  end
end
if found_auth then
else
  print("Unable to grab token. Check your credentials and try again.")
  os.exit()
end

local auth_data = json.decode(auth_req.Body)
print("\n\nWelcome, "..auth_data.displayName)

local student

-- very janky but for pairs loops for some reason dont sort by order and i aint bothered to fix it
print("[1] Get School Information")
print("[2] Select Student")
print("[3] Get Timetable")
print("[4] Attendance")
local school_data_print_guide = {
  {"Tenant ID","tenantId"},
  {"Name","name"},
  {"Phone #","phoneNumber"}
}

while true do
  print("Please select an option.")
  local selected = wrap.get_input("option")
  if selected == "1" then
    local school_info = wrap.http_request({
      Url = apiends.tenant,
      Method = "GET",
      Headers = {
        {"Content-Type","application/json, text/plain, */*"},
        {"User-Agent","Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.134 Safari/537.36"},
        {"Authorization",token}   
      }
    })
    local school_data = json.decode(school_info.Body)
    for i,v in pairs(school_data_print_guide) do
      print(v[1]..": "..school_data[v[2]])
    end
    print("Roles")
    for i,v in pairs(school_data.roles) do
      print(v)
    end
  elseif selected == "2" then
    local learners = wrap.http_request({
      Url = apiends.learners,
      Method = "GET",
      Headers = {
        {"Content-Type","application/json, text/plain, */*"},
        {"User-Agent","Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.134 Safari/537.36"},
        {"Authorization",token}   
      }
    })
    local data = json.decode(learners.Body)
    local learners_to_select = {}
    print("Select a learner: ")
    for i,v in pairs(data) do
      learners_to_select[i] = {id = v.learnerId, name = v.displayName}
      print("["..i.."] "..v.displayName)
    end
    local selected_learner = wrap.get_input("learner")
    student = learners_to_select[tonumber(selected_learner)]
    print(student.name.." selected. ID: "..student.id)
  elseif selected == "3" then
    local timetable_api = apiends.parental..""..student.id.."/timetable"
    local start_date = wrap.get_input("date (YYYY-MM-DD)")
    local end_date = start_date
    
    timetable_api = timetable_api.."?startDate="..start_date.."&endDate="..end_date
    local timetable_req = wrap.http_request({
      Url = timetable_api,
      Method = "GET",
      Headers = {
        {"Content-Type","application/json, text/plain, */*"},
        {"User-Agent","Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.134 Safari/537.36"},
        {"Authorization",token}   
      }
    })
    local tt_raw_data = json.decode(timetable_req.Body)
    -- really hacky
    local dates = {}
    for i,v in pairs(tt_raw_data) do
      table.insert(dates,v.startTime)
    end
    local sorted_dates = wrap.order_date(dates)
    table.sort(sorted_dates)
    for i,v in pairs(sorted_dates) do
      for i2,v2 in pairs(tt_raw_data) do
        if v == wrap.split_date(v2.startTime) then
          -- \x1b[38;2;r;g;bm
          local r,g,b = wrap.hex_to_rgb(v2.color)
          print("\x1b[38;2;"..r..";"..g..";"..b.."m")
            print("["..i.."] "..v2.subject.." | Teacher: "..v2.teacher.teacherName.." ("..v2.teacher.workforcePersonalId..") Time: "..v)
          print("\x1b[38;2;255;255;255m")
        end
      end
    end
  elseif selected == "4" then
    local attendance_api = apiends.parental..""..student.id.."/attendance/48422/overview"
    local attendance_req = wrap.http_request({
      Url = attendance_api,
      Method = "GET",
      Headers = {
        {"Content-Type","application/json, text/plain, */*"},
        {"User-Agent","Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.134 Safari/537.36"},
        {"Authorization",token}   
      }
    })
    local attend_raw_data = json.decode(attendance_req.Body)
    print("Total days: "..attend_raw_data.totalSchoolDays)
    print("\x1b[38;2;255;255;0mLates: "..#attend_raw_data.lateAbsences)
    print("\x1b[38;2;0;255;0mPresent: "..#attend_raw_data.presentDays)
    print("\x1b[38;2;255;255;100mPartialy Present: "..#attend_raw_data.partiallyAbsentDays)
    print("\x1b[38;2;255;0;0mUnexplained Absent: "..#attend_raw_data.unexplainedAbsences)
    print("\x1b[38;2;255;0;0mAbsent: "..#attend_raw_data.absentDays)   
    print("\x1b[38;2;255;255;255m")
  end
end
