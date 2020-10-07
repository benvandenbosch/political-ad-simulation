; Ben Vandenbosch
; CS 390 Term Project
;
; See 'Info" for sources, overview, and more



; -------------------------------------------------------------
; SECTION 1: GLOBALS, SETUP, INITIALIZATIONS
; -------------------------------------------------------------

extensions [csv]         ; Load CSV extentsion because I use data from a CSV to set up the world

globals [
; n                      ; Number of people in the model
  states-data            ; Data on states taken from CSV
  available-people       ; AgentSet of people whose friendship capacity has not been exceeded
  weeks-left              ; weeks remaining in current ad campaign
  share-prob             ; Probability that someone shares a post if it's within the scope of political views they strongly agree with
  potential-exposed      ; AgentSet of people that will be exposed to the advertisement
  mid-liberal            ; Midpoint of liberal views
  mid-conserv            ; Midpoint of conservative views
  exposures-per-week      ; Number of people to be exposed to the advertisement per week
; polarization           ; Setting for where the mean political view on each side of the spectrum lies.
                         ; 0 is the min polarization which means political views on both sides will be Normally distributed with a mean of zero
; center-friend-num ; The mean target number of friends each person will have
; perc-state-friends     ; Percentage of friends (approximately)  each person will have who are from the same state
; advert-length          ; Amount of weeks the ad runs for
; campaign-length        ; Number of ads that will be run in a given campaign
; content-persistance    ; Number of weeks that an ad will be visible to an agent's friends
; advert-strength        ; Controlled by chooser in UI - either "normal" or "strong". This changes how people react to the ad
; advert-strat           ; Controlled by chooser in UI - takes "smear" or "normal" representing what type of ad it is. People react differently to each type of ad
; benefit-candidate      ; Controlled by chooser in UI - changes which candidate the advertisements benefit. Candidate A represents the liberal candidate and Candidate B the conservative candidate
; exposure-group         ; Controlled by the chooser in UI - Controls which people can be exposed to the ad. Can choose between everyone or people from a certain side of the political spectrum
; moderate-extrema       ; Anyone with a political stance within a distance of moderate-extrema from 0 is considered moderate. If they are > moderate-extra, they're conservate. If they are < negative(moderate-extrema), they're liberal
; blocking?              ; If blocking is on, people may choose to block users who share content that differs greatly from their political views
  share-normal-prob      ; The probability that a person who sees the ad and has aligned political views shares it with their network for normal ads
  share-strong-prob      ; The probability that a person who sees the ad and has aligned political views shares it with their network for strong ads
  see-share-prob         ; The probability that a person sees the shared content of any friend on any given week
  moderate-extrema       ; 0 +/- moderate-extrema are the boundaries for what is considered a moderate
  impressions            ; Number of times people have viewed a unique ad from current campaign
  shares                 ; Number of times people have shared a unique ad from this campaign
  block-prob             ; Probability that someone of extreme viewpoints blocks people who share content they disagree with
]

breed [people person]    ; Create breed people that represents people in the United States
breed [states state]     ; Create a breed for holding information on each state. These agents do nothing other than hold information, I
                         ; am just using turtles as a data structure here.

people-own [
  residence                         ; Name of the state of residence of this person (the state they are located in)
  target-friends-num                ; Number of friends this person was intended to have from stochastic assignment
  friend-count                      ; Number of friends/connections/link-neighbors this person has
  seen-ad?                          ; Boolean representing whether or not this person has seen content from the current advertisement
  shared?                           ; Boolean representing whether or not this person has shared content from the current advertising campaign
  served?                           ; Boolean representing whether or not this person was served the ad by the network (as opposed to by another friend's activity)
  activity-visibility-remaining     ; Number that represents how much longer the ad is visible to this person's friends if this person has shared it
  political-stance                  ; Holds political sentiment of the person
  people-blocked                    ; AgentSet of people this person has blocked
]

patches-own [
  state-name                        ; The state in which the patch resides
]

states-own [            ;
  name                  ; Name of the state
  candidate-a-prop      ; Proportion of population that supports Candidate A
  candidate-b-prop      ; Proportion of population that supports Candidate B
  pop-prop              ; Proportion of the overall contiguous 48 population that this state makes up
  population            ; Numeric value of the population of the state
  residents             ; AgentSet of the people who reside in the state. This is created during setup for efficiency purposes
  state-patches         ; AgentSet of patches that comprise the state. This is created during setup for efficiency of use later.
]

; OBSERVER CONTEXT
; This procedure creates and initializes the model. It draws the US map, creates all of the agents (people) and
; distributes them and assigns political views based on US population figures. It then creates friendships between these people
; (represented by links) and finally colors the map according to the political views of each state. It's worth knowing that there
; is another setup procedure for running ads such that the user can use the map multiple times for different ad models once this
; setup procedure has been run (it takes a little while).
to setup
  ca                           ; Clear the world to get ready for setup
  reset-ticks                  ; Reset ticks to 0 to prepare for simulation
  setup-patches                ; Load the image of the map and use it to assign patches the state they represent
  load-csv                     ; Load population and political data from the CSV
  initialize-people            ; Create and distribute people based on the population density of each state
  initialize-politics          ; Assign each person a political stats based on statewide statistics in addition to some stochastic elements
  shade-states                 ; Shade the map according to the politics of each region
  initialize-friendships       ; Create the network of connections between people in this social network
  set mid-liberal -0.5         ; Set mid-liberal, which I treat as the differentiator between someone of very strong political beliefs and someone with less intense beliefs (eg. "moderate liberal" vs "serious liberal")
  set mid-conserv 0.5          ; Same thing as previous one but for conservatives.
  set share-normal-prob 0.2    ; Initialize share-normal-prob to 0.2
  set share-strong-prob 0.5    ; Initialize share-strong-prob to 0.5 (stronger because more opinionated people have a higher probability of being vocal)
  set see-share-prob 0.3       ; Initialize probability that a person sees a given neighbor's shared content on a given week
  set moderate-extrema 0.2     ; 0 +/- moderate-extrema are the boundaries for what is considered a moderate
  set impressions 0            ; Initialize impressions to zero
  set shares 0                 ; Initialize shares to zero
  set block-prob 0.5           ; Initialize block-prob to 0.5
  show "World fully initialized. You may now begin setting up ad campaigns."
end


; OBSERVER CONTEXT
; Creates and distributes people in states based on the population density of their states. Uses the state-patches AgentSet
; of each state to pick random patches for the new residents.
to initialize-people
  show "Creating and distributing people based on US population data..."
  ask states [
    let this-state-name name                                            ; Save the name of the state we are currently working on
    set population ceiling (pop-prop * n)                               ; Set the population of the state by multiplying the proportion the country's population
                                                                        ; it contains by the number of people set by 'n'. Round up because for low-population states it is
                                                                        ; better to overrepresent the population to minimize the effects of outliers.

    hatch-people population [                                           ; Create and randomly distribute the population of the state
      set hidden? false                                                 ; Must set hidden to false because states are hidden and we do not want this inherited
      set color blue                                                    ; Set aesthetic characteristics ....
      set heading 0
      set size 2
      set residence this-state-name                                     ; Initialize residence to this state
      move-to one-of [state-patches] of myself                          ; Move to random patch of this state
      set target-friends-num random-normal center-friend-num 5          ; Set the target number of friends of the person (using Normal distribution with mean center-friend-num)
      if target-friends-num < 0 [set target-friends-num 0]              ; Don't let anyone have negative friends - this means the distribution ends up NOT being Normal, but that's okay because
                                                                        ; in real life people like celebrities have far more friends than some people and some people never check their social media. (Big abstraction, I know)
      set people-blocked no-turtles                                     ; Nobody should be blocked initially
      set seen-ad? false
      set served? false                                                 ; Initialize seen-ad?, shared? and served? false because nobody has been exposed to an ad
      set shared? false
    ]
  ]
end


; OBSERVER CONTEXT
; Initialize the political views of each person based on the political representation of states. There are some pretty big assumptions and
; simplifications here. I found the percentage of people from each state that identify as Democrats and Republicans. Those percentages of people
; are Normally distributed at a distance from 'polarization' from zero on their respective sides of the political spectrum. Everyone else
; is Normally distributed around 0. Then, I form AgentSets based on where people's political stances lie in relation to moderate-extrema.
to initialize-politics
  show "Initializing state politics..."
  ask states [                                                                                                                                       ; Ask all states
    let this-state-name name                                                                                                                         ; Save the name of this state
    set residents people with [residence = this-state-name]                                                                                          ; Set residents to the AgentSet of people who reside in this state
    let num-liberal floor (candidate-a-prop * population)                                                                                            ; Calculate # of liberals
    let num-conserv floor (candidate-b-prop * population)                                                                                            ; Calculate # of conservatives
    let num-moderate (population - num-liberal - num-conserv)                                                                                        ; Set # of moderates to everyone else remaining

    let liberal-set n-of num-liberal residents                                                                                                       ; Randomly create an AgentSet of people to be liberals
    let conserv-set n-of num-conserv people with [residence = this-state-name and not member? self liberal-set]                                      ; Randomly create an AgentSet of people to be conservatives
    let moderate-set n-of num-moderate people with [residence = this-state-name and not member? self liberal-set and not member? self conserv-set]   ; Create an AgentSet of everyone else to be moderates

    ask moderate-set [set political-stance random-normal 0 0.065]                                                                                    ; Randomly distribute moderates' political-stances around 0

    ask liberal-set [set political-stance (0 - (random-normal polarization .1))]                                                                     ; Randomly distribute liberals' political-stances around negative(polarization)

    ask conserv-set [set political-stance random-normal polarization .1]                                                                             ; Randomly distribute conservatives' political-stances around polarization
  ]

    ; Color people based on their political stances (Blue --> Candidate A/Liberal | Red --> Candidate B/Conservative | White --> Moderate/Candidate A if < 0 and Candidate B if > 0
    ask people with [political-stance >= (0 - moderate-extrema) and political-stance <= moderate-extrema] [set color white]
    ask people with [political-stance < (0 - moderate-extrema)] [set color blue]
    ask people with [political-stance > moderate-extrema] [set color red]

end

; OBSERVER CONTEXT
; This procedure contains the logic that builds the social network. It creates uses the
to initialize-friendships
  show "Building social network..."
  set available-people people                                                                                      ; Create an AgentSet that will represent people whose friend quota has not been met or surpassed
                                                                                                                   ; .... target-friends-num represents such a quota which was initialized in 'initialie-people'
  let num-other-friends 0                                                                                          ; This will represent the number of friends for a person that will come from out of state
  ask people [                                                                                                     ; Ask every person:
    set friend-count count link-neighbors                                                                          ; Update their friend-count to equal the number of link-neighbors they have
    if friend-count < target-friends-num  [                                                                        ; If they have not met their friend quota:
      set available-people available-people with [self != myself]
      let this-state one-of states with [name = [residence] of myself]                                             ; Save the name of their state of residence (for ease of reference)
      let new-connections-num target-friends-num - friend-count                                                    ; Calculate the number of new friendships they need
      let num-friends-instate round (perc-state-friends * new-connections-num / 100)                               ; Calculate the number of these new friendships that should be in state
      set num-other-friends new-connections-num - num-friends-instate                                              ; Calculate the number of these friendships that will come from out of state

      let potential-instate (available-people with [member? self [residents] of this-state])                       ; Create an AgentSet of potential new instate friends (people who are in the state, not self, and not already friends)
      let potential-instate-count count potential-instate

      ifelse potential-instate-count >= num-friends-instate [                                                      ; If there are enough potential instate friends,
        create-links-with n-of num-friends-instate potential-instate [create-friendship]                           ;   form num-friends-instate friendships with them randomly
    ]
      [
          create-links-with n-of potential-instate-count potential-instate [create-friendship]                     ; Otherwise, form friendships with the remaining ones and increase the number of out-of-state
        set num-other-friends num-other-friends + (num-friends-instate - potential-instate-count)                  ; friends targeted such that the friendship quota can still be met
      ]

    ifelse count available-people >= num-other-friends [                                                           ; Make friends with num-other-friends remaining people in available-people
        create-links-with n-of num-other-friends available-people [create-friendship]
        ]
    [
            create-links-with n-of count available-people available-people [create-friendship]                     ; If there aren't enough, make friends with as many people as possible
    ]
        ]
        ]
 show(word "Social network fully created. There are " count links  " friendships.")
 wait 1
 ask links [set hidden? true]
end


; LINK/FRIENDSHIP CONTEXT
; Called when a person's friendships are being created in the initialize-friendships procedure. The person asks the link
; to call this procedure. This procedure asks the person at the other end of the link to update their friend-count variable
; and remove itself from the available-people AgentSet if its target number of friends has been achieved.
to create-friendship
  ask other-end [                                                                                               ; Ask the person at the other end the link
            set friend-count count link-neighbors                                                               ; Update number of friends by counting links
            if friend-count >= target-friends-num [set available-people available-people with [self != myself]  ; Remove self from available-people if quota of friends has been achieved
        ]
    ]
end

; OBSERVER CONTEXT
; Load the CSV file and set patch instance variables This loads a CSV with population and political information
; on each state and creates a state object to hold them. It then creates a patchset, held as a instance variable
; of the state, and puts every patch that's a part of the state into it.
to load-csv
  show "Reading data on state populations and creating sets of patches in each state..."
  set states-data csv:from-file "states-data.csv"
  foreach states-data [input-list ->                                      ; For each row in the CSV
    create-states 1 [                                                     ; Create a state variable
      set name item 0 input-list                                          ; And import state name, political views, population data
      set candidate-a-prop item 2 input-list
      set candidate-b-prop item 3 input-list
      set pop-prop item 5 input-list
      set hidden? true                                                    ; States should be hidden because they are just being used as data structures
      set state-patches patches with [state-name = [name] of myself]      ; Create a patchset that holds every patch in the state
    ]
  ]
end

; OBSERVER CONTEXT
; Import an image of the United States map and color patches to draw the map. Assign patches to a state based on the colors and position in the world.
; This is just a brute force approach for assigning patches to states because I could not figure out GIS (otherwise I would have used a GIS population
; density map instead of much of the CSV values logic)
to setup-patches
  show "Drawing map..."
  import-pcolors "united-states-map.png"
  show "Assigning patches to states..."

  ; Assign patches to states based on their color and location in the world.
  ask patches with [pcolor = white] [set pcolor black]
  ask patches with [pcolor = 47.2] [set state-name "Washington"]
  ask patches with [pcolor = 28.3] [set state-name "Oregon"]
  ask patches with [pcolor = 136.3] [set state-name "California"]
  ask patches with [pcolor = 117.2] [set state-name "Nevada"]
  ask patches with [pcolor = 17.8] [set state-name "Idaho"]
  ask patches with [pcolor = 135.8] [set state-name "Montana"]
  ask patches with [pcolor = 107.5] [set state-name "Wyoming"]
  ask patches with [pcolor = 68.6] [set state-name "Utah"]
  ask patches with [pcolor = 137.4] [set state-name "Arizona"]
  ask patches with [pcolor = 108.2] [set state-name "Colorado"]
  ask patches with [pcolor = 108] [set state-name "New Mexico"]
  ask patches with [pcolor = 27.9] [set state-name "North Dakota"]
  ask patches with [pcolor = 135.8 and pxcor > -128] [set state-name "South Dakota"]
  ask patches with [pcolor = 108 and pycor > 0] [set state-name "Nebraska"]
  ask patches with [pcolor = 108 and pycor > 96] [set state-name "Minnesota"]
  ask patches with [pcolor = 87.7] [set state-name "Kansas"]
  ask patches with [pcolor = 27.7] [set state-name "Oklahoma"]
  ask patches with [pcolor = 87.6] [set state-name "Texas"]
  ask patches with [pcolor = 137.1] [set state-name "Iowa"]
  ask patches with [pcolor = 137.6] [set state-name "Missouri"]
  ask patches with [pcolor = 47.4] [set state-name "Arkansas"]
  ask patches with [pcolor = 47.1] [set state-name "Louisiana"]
  ask patches with [pcolor = 137.4 and pxcor > -90] [set state-name "Michigan"]
  ask patches with [pcolor = 88.2] [set state-name "Wisconsin"]
  ask patches with [pcolor = 48.1] [set state-name "Illinois"]
  ask patches with [pcolor = 17.5] [set state-name "Indiana"]
  ask patches with [pcolor = 128] [set state-name "Kentucky"]
  ask patches with [pcolor = 27.9 and pxcor > 70] [set state-name "Tennessee"]
  ask patches with [pcolor = 27.2] [set state-name "Mississippi"]
  ask patches with [pcolor = 128 and pycor < 46 ] [set state-name "Alabama"]
  ask patches with [pcolor = 67.8] [set state-name "Ohio"]
  ask patches with [pcolor = 136.9] [set state-name "Georgia"]
  ask patches with [pcolor = 86.6] [set state-name "Florida"]
  ask patches with [pcolor = 87] [set state-name "West Virginia"]
  ask patches with [pcolor = 67.5] [set state-name "South Carolina"]
  ask patches with [pcolor = 117.5] [set state-name "North Carolina"]
  ask patches with [pcolor = 128.2] [set state-name "Virginia"]
  ask patches with [pcolor = 136.6] [set state-name "Maryland"]
  ask patches with [pcolor = 127.9] [set state-name "Pennsylvania"]
  ask patches with [pcolor = 68.2] [set state-name "Delaware"]
  ask patches with [pcolor = 68.5] [set state-name "New Jersey"]
  ask patches with [pcolor = 28.8] [set state-name "Connecticut"]
  ask patches with [pcolor = 128.7] [set state-name "Massachusetts"]
  ask patches with [pcolor = 67.8 and pxcor > 306] [set state-name "Maine"]
  ask patches with [pcolor = 117.9] [set state-name "New Hampshire"]
  ask patches with [pcolor = 118.5] [set state-name "Vermont"]
  ask patches with [pcolor = 47.5] [set state-name "New York"]
  ask patches with [pcolor = 117.8] [set state-name "Rhode Island"]
  ask patches with [pcolor = white] [set pcolor black]
end


; -------------------------------------------------------------
; SECTION 2: ADVERTISEMENTS, CAMPAIGNS, AND REACTIONS
; -------------------------------------------------------------



; OBSERVER CONTEXT
; Set up a political ad/fake news campaign
to setup-campaign
  reset-ticks                                                                           ; Reset ticks for each campaign
  reset-politics                                                                        ; Reset the political views of people
  set shares 0                                                                          ; Reset the number of shares
  set impressions 0                                                                     ; Reset the number of impressions
  if exposure-group = "Everyone" [set potential-exposed people]                         ; Create an AgentSet of people that can be exposed to the advertisement...
  if exposure-group = "Candidate A Supporters" [
    set potential-exposed people with [political-stance <= (0 - moderate-extrema)]]
  if exposure-group = "Candidate B Supporters" [
    set potential-exposed people with [political-stance >= moderate-extrema]]
end


; OBSERVER CONTEXT
; This is the "go" procedure for the campaign. It runs all the precedures necessary for a campaign and
; stops when the campaign has been completed.
to run-campaign
  if ticks >= (campaign-length * advert-length) [        ; If the last ad has expired
    show "Campaign finished."                            ; Tell the user the campaign is over
    stop                                                 ; Stop the campaign
  ]
  if ticks mod advert-length = 0 [                       ; After each ad has finished, end it
    end-advertisement
  ]
  serve-ads                                              ; Serve the advertisement
  handle-share-reactions                                 ; Handle reactions to it
  shade-states                                           ; Reshade the map
  update-people-colors                                   ; Update the colors of the agents
  tick
end


; OBSERVER CONTEXT
; This is the procedure that serves advertisements to people who have not seen them yet
to serve-ads
  if count people with [served?] < exposure-magnitude [
      ask n-of exposure-magnitude potential-exposed [set served? true react]  ; Expose a random amount of people in exposure group to the advertisement
  ]
end


; OBSERVER CONTEXT
; This procedure ends an advertisement by clearing the instance variables of people that relate to advertisements such that they
; interpret the next advertisement as being completely new while maintaining any changes in their political stance that came from the previous
; advertisement.
to end-advertisement
  ask people [
    set shared? false                        ; Set shared? to false for new ad because nobody has seen it yet
    set seen-ad? false                       ; Set seen-ad? to false for new ad because nobody has seen it yet
    set activity-visibility-remaining 0      ; Set activity-visibility-remaining to 0
    set served? false                        ; Set served? to false for new ad because nobody has seen it yet
  ]
end


; PEOPLE/TURTLE CONTEXT
; This procedure handles how people react to an advertisement they are exposed to. This will be complex.
to react
  set seen-ad? true                                                                   ; Set seen-ad? to true because person has now seen the advertisement
  set impressions impressions + 1                                                     ; Increment # of impressions
  if shareable? [                                                                     ; If the advertisement is shareable
  ifelse advert-strength = "strong" [share-strong ] [share-normal ]                   ; Call the correct sharing procedure
]

  let result 0
  ifelse advert-strat = "support" [set result react-support] [set result react-smear] ; Get the person's reaction to the advertisement

  set political-stance political-stance + result                                      ; Adjust political-stance according to reaction
  if political-stance < -1 [set political-stance -1]                                  ; Cap the range of political stances to be between 1 and -1
  if political-stance > 1 [set political-stance 1]
end


; PEOPLE/PERSON CONTEXT
; Handle reactions to ads supportive of a candidate
to-report react-support
  let direction 0
  let reaction-strength stance-change-magnitude

  if benefit-candidate = "Candidate A" [                                                                  ; If the benefit-candidate is Candidate A
    if advert-strength = "normal" [                                                                       ; . and the advert-strength is normal
      if political-stance > mid-liberal and political-stance < mid-conserv [set direction -1]]            ; .. then move everyone with a midrange stance 1 unit towards that candidate
    if advert-strength = "strong" [                                                                       ; . if the advert-strength is strong
      if political-stance > (0 - moderate-extrema) and political-stance < moderate-extrema [              ; .. and the political stance is moderate
        ifelse probability? 0.5 [set direction -1] [set direction 1]                                      ; ... then they'll move twice as far in a random direction
        set reaction-strength 2 * stance-change-magnitude]
      if political-stance <= (0 - moderate-extrema) and political-stance >= mid-liberal [set direction -1]; .. if political stance is midrange liberal, move 1 unit toward -1
      if political-stance >= moderate-extrema and political-stance <= mid-conserv [set direction 1]       ; .. if it's midrange conservative, move 1 unit toward 1
      if political-stance < mid-liberal [set direction -1]                                                ; .. if it's very liberal, move 1 unit toward -1
      ; people with very conservate stances will not move at all
    ]
  ]

    ; SAME LOGIC BUT IN THE OTHER DIRECTION FOR CANDIDATE B

  if benefit-candidate = "Candidate B" [                                                                 ; If the benefit-candidate is Candidate B
   if advert-strength = "normal" [                                                                       ; . and the advert-strength is normal
     if political-stance > mid-liberal and political-stance < mid-conserv [set direction 1]]             ; .. then move everyone with a midrange stance 1 unit towards 1
   if advert-strength = "strong" [                                                                       ; . if the advert-strength is strong
     if political-stance > (0 - moderate-extrema) and political-stance < moderate-extrema [              ; .. and the political stance is moderate
       ifelse probability? 0.5 [set direction -1] [set direction 1]                                      ; ... then they'll move twice as far in a random direction
       set reaction-strength 2 * stance-change-magnitude]
     if political-stance <= (0 - moderate-extrema) and political-stance >= mid-liberal [set direction -1]; .. if political stance is midrange liberal, move 1 unit toward -1
     if political-stance >= moderate-extrema and political-stance <= mid-conserv [set direction 1]       ; .. if it's midrange conservative, move 1 unit toward 1
     if political-stance > mid-conserv [set direction 1]                                                 ; .. if it's very conservative, move 1 unit toward 1
     ; people with very conservate stances will not move at all
   ]
 ]

  report (direction * reaction-strength)
end

; PEOPLE/PERSON CONTEXT
; Handles reactions to ads smearing the other candidate
to-report react-smear
  let direction 0
  let reaction-strength stance-change-magnitude

  if benefit-candidate = "Candidate A" [                                                                     ; If the benefit-candidate is Candidate A
    if advert-strength = "normal" [                                                                          ; . and the advert strength is normal
      if political-stance >= mid-liberal and political-stance < moderate-extrema [                           ; .. and the political-stance is midliberal through moderate
        set direction -1]                                                                                    ; ... move it 1 unit toward -1
      if political-stance <= mid-conserv and political-stance >= moderate-extrema [                          ; .. if the political-stance is midrange conservative
        set direction -1                                                                                     ; ... move it 0.5 units unit toward -1
        set reaction-strength (0.5 * stance-change-magnitude)]
    ]
    if advert-strength = "strong" [                                                                          ; . if the advert strength is strong
      if political-stance > (0 - moderate-extrema) and political-stance < moderate-extrema [                 ; .. and the political stance is moderate
        ifelse probability? 0.5 [set direction -1] [set direction 1]                                         ; ... move it 2 units randomly
        set reaction-strength (2 * stance-change-magnitude)]
      if political-stance <= (0 - moderate-extrema) and political-stance >= mid-liberal [                    ; .. if the political stance is midrange liberal
        set direction -1                                                                                     ; ... move it 1.5 units toward -1
        set reaction-strength (1.5 * stance-change-magnitude)]
      if political-stance < mid-liberal [set direction -1]                                                   ; ... if the political stance is very liberal move it 1 unit toward -1
      if political-stance >= moderate-extrema [set direction 1]                                              ; ... if it's at all conservate, move it 1 unit toward 1
    ]
  ]

 ; SAME LOGIC BUT FOR CANDIDATE B
  if benefit-candidate = "Candidate B" [                                                                     ; If the benefit-candidate is Candidate B
    if advert-strength = "normal" [                                                                          ; . and the advert strength is normal
      if political-stance > (0 - moderate-extrema) and political-stance <= mid-conserv [                     ; .. and the political-stance is moderate through midrange conserv
        set direction 1]                                                                                     ; ... move it 1 unit toward 1
      if political-stance <= (0 - moderate-extrema) and political-stance >= mid-liberal [                    ; .. if the political-stance is midrange liberal
        set direction 1                                                                                      ; ... move it 0.5 units unit toward 1
        set reaction-strength (0.5 * stance-change-magnitude)]
    ]
    if advert-strength = "strong" [                                                                          ; . if the advert strength is strong
      if political-stance > (0 - moderate-extrema) and political-stance < moderate-extrema [                 ; .. and the political stance is moderate
        ifelse probability? 0.5 [set direction -1] [set direction 1]                                         ; ... move it 2 units randomly
        set reaction-strength (2 * stance-change-magnitude)]
      if political-stance >= moderate-extrema and political-stance <= mid-conserv [                          ; .. if the political stance is midrange conserv
        set direction 1                                                                                      ; ... move it 1.5 units toward 1
        set reaction-strength (1.5 * stance-change-magnitude)]
      if political-stance > mid-conserv [set direction 1]                                                    ; ... if the political stance is very conserv move it 1 unit toward 1
      if political-stance <= (0 - moderate-extrema) [set direction -1]                                       ; ... if it's at all liberal, move it 1 unit toward -1
    ]
  ]

  report (direction * reaction-strength)
end


; PEOPLE/TURTLE CONTEXT
; This procedure is only called if the advertisement is of normal strength. It is called by people who have reacted to
; the advertisement. If the person's political views lean toward the benefit-candidate and are not in the moderate or strong range,
; then there is a probability of share-normal-prob that they choose to share the ad with their network.
to share-normal
  if benefit-candidate = "Candidate A" and political-stance > mid-liberal and political-stance < (0 - moderate-extrema) [ ; If the person's political-stance is between mid-liberal and the low moderate-extrema and Candidate A is
                                                                                                                          ; .... the beneficiary of the ad
    if probability? share-normal-prob [set shared? true set activity-visibility-remaining content-persistence set shares shares + 1]            ; Then there's a share-normal-prob probability they share it with their network, in which case
                                                                                                                          ; .... shared? is set to true and activity-visibility-remaining is set to content-persistence
  ]
  if benefit-candidate = "Candidate B" and political-stance < mid-conserv and political-stance > moderate-extrema [       ; Same logic but for Candidate B...
    if probability? share-normal-prob [set shared? true set activity-visibility-remaining content-persistence set shares shares + 1]
  ]
end


; PEOPLE/TURTLE CONTEXT
; This procedure is called if the advertisement is of strong strength and the person has reacted to the ad. If the person's
; political views are very strong (past mid-liberal or mid-conserv) and in line with that of the benefit-candidate, then
; there's a probability of share-strong-prob that they choose to share it with their network.
to share-strong
  if benefit-candidate = "Candidate A" and political-stance < mid-liberal [
    if probability? share-strong-prob [
      set shared? true
      set activity-visibility-remaining content-persistence
      set shares shares + 1]
  ]
  if benefit-candidate = "Candidate B" and political-stance > mid-conserv [
    if probability? share-strong-prob [
      set shared? true
      set activity-visibility-remaining content-persistence
      set shares shares + 1]
  ]
end


; OBSERVER CONTEXT
; This procedure handles the logic for dealing with the friends of people who shared the advertisement.
; It asks all people who have shared the ad to ask their link neighbors who have not yet seen it to
; react to the advertisement. This is what would count as an organic view rather than a served view.
to handle-share-reactions
  ask people with [shared? and activity-visibility-remaining > 0] [                                 ; Ask people who shared the ad within the window of time for the ad to still be visible
    set activity-visibility-remaining activity-visibility-remaining - 1                             ; Decrement the activity-visibility-remaining counter
    ask link-neighbors with [not seen-ad? and not member? myself people-blocked] [                  ; Ask link-neighbors who have not seen the ad
      if probability? see-share-prob [                                                              ; Determine if a given neighbor sees the shared content
        ask link who [who] of myself [set color yellow]                                             ; Set the link between these two people to yellow (representing that the ad was organically shared between the two)
        block
        react                                                                                       ; Tell these link neighbors to react (has them call the 'react' procedure)
      ]
    ]
  ]
end


; AGENT/PEOPLE CONTEXT
; Block the person who shared the content if you disagree with it strongly
to block
  let block? false
  if political-stance < mid-liberal and benefit-candidate = "Candidate B" and advert-strength = "strong" [set block? true]  ; If views are different enough, consider blocking
  if political-stance > mid-conserv and benefit-candidate = "Candidate A" and advert-strength = "strong" [set block? true]  ; If views are different enough, consider blocking

  if block? and probability? block-prob [
    let shared-person nobody                                                               ; Create a variable to hold the person who shared the content
    ask link [who] of self [who] of myself [                                               ; Ask the link between self and person who shared the content
      set color blue                                                                       ; This will represent a block
      set shared-person other-end                                                          ; Set shared-person to person who shared the content
    ]
    set people-blocked people with [member? self people-blocked or self = shared-person]   ; Add shared-person to blocked-list
  ]
end

; OBSERVER CONTEXT
; Resets the politics of the people on the map so the user can run another trial without having to set up the map and
; friendship graph again. Resets colors of edges on the graph to black.
to reset-politics
  initialize-politics                       ; Overwrite the regional politics with normal initialization procedure
  shade-states                              ; Reshade the map
  ask people [                              ; Reset necessary instance variables of people (ad-related variables)
    set shared? false
    set seen-ad? false
    set activity-visibility-remaining 0
    set served? false
  ]
  set impressions 0
  set shares 0
  ask links [set color black]               ; Recolor links to black
end


; OBSERVER CONTEXT
; Toggle between showing and not showing links between people through which ad(s) were shared
to switch-share-visibility
  ask links with [color = yellow] [    ; Ask links through which ad content was shared (the yellow ones) to be hidden if they are not hidden or vice versa
    ifelse hidden? [
      set hidden? false]
    [
      set hidden? true]
  ]
end

; OBSERVER CONTEXT
; Toggle between showing and not showing links between people where at least one has blocked the other
to switch-block-visibility
  ask links with [color = blue] [    ; Ask links where a block occurred (the blue ones) to be hidden if they are not hidden or vice versa
    ifelse hidden? [
      set hidden? false]
    [
      set hidden? true]
  ]
end

; -------------------------------------------------------------
; SECTION 3: HELPERS, UTILITIES, AND REPORTERS
; -------------------------------------------------------------


; OBSERVER CONTEXT
; Shade states according to political sentiment within state. This is not a representation of the number of people that lean each way,
; but rather an average of the political-stance of people in each state. Thus, the severity of one's political view counts.
to shade-states
  ask states [                                                                                  ; Ask all states
    let this-state name                                                                         ; Save the name of the state we are working with
    let political-sum 0                                                                         ; Initialize a variable that will hold the sum of the political stances of every resident
    ask residents [set political-sum political-sum + political-stance]                          ; Ask residents to contribute their political stance to that variable
    let political-avg (precision (political-sum / population) 5)                                ; Take the average political-stance by dividing political-sum by the state population
    if political-avg > 0 [ask state-patches [set pcolor scale-color red political-avg 1 0 ]]    ; If the average political-stance is greater than zero, we assign the state a shade of red (1=darkest 0=lightest)
    if political-avg < 0 [ask state-patches [set pcolor scale-color blue political-avg -1 0]]   ; If the average political-stance is less than zero, we assign the state a shade of blue (-1=darkest 0=lightest)
    if political-avg = 0 [ask state-patches [set pcolor white]                                  ; If the political-average is zero, color the state white
    ]
  ]
 end


; OBSERVER CONTEXT
; Update the coloring of people based on their political views. This is called
; with each week of an advertising campaign to show updated status.
to update-people-colors
  ask people [
    if political-stance < (0 - moderate-extrema) [set color blue]                                              ; Set color to blue if person is considered liberal (and not in moderate range)
    if political-stance > moderate-extrema [set color red]                                                     ; Set color to red if person is considered conservative (and not in moderate range)
    if political-stance >= (0 - moderate-extrema) and political-stance <= moderate-extrema [set color white]   ; Set color to white if person is in moderate range
  ]
end


; OBSERVER CONTEXT
; Reports the average politcal-stance of people who support candidate A (anyone with a political-stance < 0)
; This reports to the monitor in the UI
to-report candidate-a-average
  let lib-sum 0                                                                                                ; Initialize variable that will hold sum of political-stances to zero
  let lib-count 0                                                                                              ; Initialize variable that will hold sum of people with political-stance < 0 to 0
  ask people with [political-stance < 0] [set lib-sum lib-sum + political-stance set lib-count lib-count + 1]  ; Ask every person who would support Candidate A to add their political-stance to lib-sum
  report lib-sum / lib-count                                                                                   ; Average the political-stances of people who would support Candidate A and report it
end


; OBSERVER CONTEXT
; Reports the average politcal-stance of people who support Candidate B (anyone with a political-stance > 0)
; This reports to the monitor in the UI. The logic is the same as for the identical reporter (but for Candidate A) that
; is directly above.
to-report candidate-b-average
  let conserv-sum 0
  let conserv-count 0
  ask people with [political-stance > 0] [set conserv-sum conserv-sum + political-stance set conserv-count conserv-count + 1]
  report conserv-sum / conserv-count
end


; ANY CONTEXT
; Does a probaility calculation. Takes a probability as an input and randomly selects a float
; between 0 and 1. If the number selected is less than the probability, reports true. Otherwise,
; reports false. This is just a handy utility for quick probability calculations to make other procedures
; less dense.
to-report probability? [prob]
  let random-num random-float 1
  ifelse random-num < prob [report true] [report false]
end
@#$#@#$#@
GRAPHICS-WINDOW
227
10
1236
1020
-1
-1
1.0
1
10
1
1
1
0
0
0
1
-500
500
-500
500
0
0
1
ticks
30.0

BUTTON
1
33
106
66
Setup World
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
4
77
104
110
n
n
0
8000
6750.0
10
1
NIL
HORIZONTAL

SLIDER
109
77
218
110
polarization
polarization
0
1
0.5
.1
1
NIL
HORIZONTAL

SLIDER
1
187
197
220
center-friend-num
center-friend-num
1
10
8.0
1
1
NIL
HORIZONTAL

SLIDER
8
284
180
317
perc-state-friends
perc-state-friends
1
100
80.0
1
1
NIL
HORIZONTAL

INPUTBOX
1263
63
1357
123
advert-length
3.0
1
0
Number

SWITCH
1265
200
1388
233
shareable?
shareable?
0
1
-1000

CHOOSER
1263
242
1407
287
advert-strength
advert-strength
"normal" "strong"
1

CHOOSER
1266
296
1404
341
advert-strat
advert-strat
"support" "smear"
1

CHOOSER
1268
352
1406
397
benefit-candidate
benefit-candidate
"Candidate A" "Candidate B"
1

CHOOSER
1268
409
1464
454
exposure-group
exposure-group
"Everyone" "Candidate A Supporters" "Candidate B Supporters"
0

BUTTON
1264
14
1404
47
set-up-campaign
setup-campaign
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1426
16
1531
49
NIL
run-campaign\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1266
586
1445
619
content-persistence
content-persistence
1
advert-length
2.0
1
1
NIL
HORIZONTAL

MONITOR
6
441
185
486
candidate-a-average
precision candidate-a-average 3
17
1
11

MONITOR
6
507
184
552
candidate-b-average
precision candidate-b-average 3
17
1
11

MONITOR
6
572
95
617
impressions
impressions
1
1
11

MONITOR
5
632
62
677
shares
shares
1
1
11

BUTTON
1264
688
1378
721
NIL
reset-politics
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1265
471
1435
504
NIL
switch-share-visibility
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
1372
63
1474
123
campaign-length
10.0
1
0
Number

SLIDER
1266
534
1460
567
stance-change-magnitude
stance-change-magnitude
.05
.2
0.1
.05
1
NIL
HORIZONTAL

SLIDER
1264
143
1449
176
exposure-magnitude
exposure-magnitude
10
n
1000.0
5
1
NIL
HORIZONTAL

TEXTBOX
1268
621
1418
663
Length of time a shared advertisement is visible to friends
11
0.0
1

TEXTBOX
18
115
86
133
# of people
11
0.0
1

TEXTBOX
114
112
220
168
0 = very moderate political views\n1 = very polarized political views
11
0.0
1

TEXTBOX
10
227
160
269
Center of distribution of # friends per person (skewed right)
11
0.0
1

TEXTBOX
15
327
165
425
Target number of in-state friends. Actual results vary based on # of people in-state and other friend assignments. Treat as a metric rather than actual percentage.
11
0.0
1

TEXTBOX
1463
157
1613
175
# of paid exposures to ad
11
0.0
1

TEXTBOX
1474
538
1624
566
Adjust strength of reactions to advertisements
11
0.0
1

TEXTBOX
1414
361
1564
389
For smear campaigns, the other candidate is smeared
11
0.0
1

SWITCH
1446
207
1562
240
blocking?
blocking?
0
1
-1000

BUTTON
1444
471
1613
504
NIL
switch-block-visibility\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## Honor Code

I have neither given nor received unauthorized aid on this project. - Ben Vandenbosch

## Sources

- Example code and lectures from Professor Dickerson in CSCI 390 Spring 2018 at Middlebury College
- The NetLogo Dictionary and Documentation found at https://ccl.northwestern.edu/netlogo/docs/
- Original Map Image from http://cdoovision.com/us-map-of-states-without-names/us-map-of-states-without-names-usa-map-without-state-names-no-name-at-of-us-labels-creatopme/
- Population Data from the United States Census Bureau
- Political Data by State from Gallup Polling http://news.gallup.com/poll/203117/gop-maintains-edge-state-party-affiliation-2016.aspx
## IMPORTANT CONTEXTUAL OVERVIEW & NOTES

INTRO
This model is an attempt to simulate the effects of paid political advertisements on a social network. The world consists of a map of the contiguous 48 states of the U.S. and has people spread across the country according to the proportion of the population that each state holds (adjusted to exclude Alaska and Hawaii). Using data on the proportion of Republicans and Democrats in each state, I assign respective proportions to be liberal or conservative, and the remaining population to be moderate.

ORDER OF OPERATIONS
To properly use the model, first adjust settings underneath the "Setup World" button and then click it. Then, adjust campaign settings (to the right of the world) and click "set-up-campaign". Then you can click "run-campaign" to watch your paid promotion affect the nation's politics.

THE POLITICAL SPECTRUM
Each person's political stance is a number between -1 and 1 (inclusive). -1 represents the most possible liberal stance and 1 the most possible conservative stance. 0 represents the perfect moderate, and generally every person within "moderate-extrema" of zero is treated as a moderate. The initial political stances are generated by first breaking down people into sets roughly based on real data (as decribed in previous paragraph). People in the moderate set have Normally distributed political stances with a mean of zero. Liberal and conservative people have Normally distributed political stances with a mean of negative(polarization) and polarization respectively. States are shaded according to the average of the political stances of all people in the state such that strength of view is weighted. I made this choice because this model was intended to simulate polarity rather than election outcome.

THE SOCIAL NETWORK
The social network is formed using the algorithm held in the "initialize-friendships" procedure. I generate a target number of friendships per person that fall in an initially Normal distribution with a mean of "center-friend-num" and standard deviation of 5. However, anyone with a target friend number below zero is reassigned to zero, meaning there is a possibility they will have no friends. So, the distribution ends up with a skew to the right, but this accounts for people with social networking accounts who rarely use them or only use them to keep track of family members. I create friendships between people, one at a time, by calculating the number of friends needed to reach the target number. Then, if there are enough people with whom they are not already friends in-state, they form "perc-friends-in-state" of their new friendships with people in state. The remaining come randomly from around the country. Friendships are represented with links. See the well-commented "initialize-friendships" procedure for more detail on this.


ADVERTISING CAMPAIGNS
This model is intended to look at how political ad campaigns will affect voting. We assume (obviously not completely realistically) that political stance directly relates to how strongly people support a candidate. So, anyone with a political stance of less than zero intends to vote for the liberal candidate, Candidate A. Likewise, anyone with a political stance greater than zero intends to vote for the conservative candidate, Candidate B.

Once setup has been completed, you can begin to create your own advertising campaign. Campaign-length governs the number of advertisements in a campaign, and advert-length controls the amount of time (in weeks) each of the advertisements lasts. So if campaign-length was 4 and advert-length was 2, your campaign would last 8 weeks (2 weeks per ad). Exposure-magnitude controls the number of people each advertisement is exposed to, and content-persistence controls the number of weeks that an advertisement will be visible to a person's friends if they have chosen to share an advertisement. Treat stance-change-magnitude like a scale for how strongly people react to advertisements. Advertisements of strength "strong" will elicit stronger reactions than those of strength "normal." And, "smear" campaigns are more polarizing than "supportive" advertisements which are more focused on giving reasons to support a candidate.

Candidate A Supporters = People with political-stance < 0
Candidate B Supporters = People with political-stance > 0


MONITORS
Here, I define what each of the monitors on the interface represent:

candidate-a-average -> the average political stance of people with a political-stance < 0

candidate-b-average -> the average political stance of people with a political-stance > 0

impressions -> # of views of ads in current advertising campaign

shares -> # of shares of ads in current advertising campaign
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="SocialExperiment" repetitions="3" runMetricsEveryStep="false">
    <setup>setup-campaign</setup>
    <go>run-campaign</go>
    <metric>candidate-a-average</metric>
    <metric>candidate-b-average</metric>
    <enumeratedValueSet variable="campaign-length">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="content-persistence">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="center-friend-num">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="polarization">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stance-change-magnitude">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposure-magnitude">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="advert-strat">
      <value value="&quot;support&quot;"/>
      <value value="&quot;smear&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="perc-state-friends">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="shareable?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="benefit-candidate">
      <value value="&quot;Candidate A&quot;"/>
      <value value="&quot;Candidate B&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="blocking?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="advert-strength">
      <value value="&quot;normal&quot;"/>
      <value value="&quot;strong&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposure-group">
      <value value="&quot;Everyone&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="advert-length">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n">
      <value value="5080"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
