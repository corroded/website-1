require 'test_helper'

class ApprovesSolutionTest < ActiveSupport::TestCase
  test "approves solution" do
    Timecop.freeze do
      solution = create :solution, last_updated_by_user_at: nil

      mentor = create :user
      create :track_mentorship, user: mentor, track: solution.exercise.track
      create :solution_mentorship, solution: solution, user: mentor

      ApproveSolution.(solution, mentor)

      solution.reload
      assert_equal mentor, solution.approved_by
      assert_nil solution.last_updated_by_user_at
      assert_equal DateTime.now.to_i, solution.last_updated_by_mentor_at.to_i
    end
  end

  test "fails for non-mentor" do
    refute ApproveSolution.(create(:solution), create(:user))
  end

  test "fails for mentor of different track" do
    mentor = create :user
    create :track_mentorship, user: mentor
    different_track_solution = create(:solution)
    refute ApproveSolution.(different_track_solution, mentor)
  end

  test "notifies and emails user upon mentor post" do
    solution = create :solution
    user = solution.user

    # Setup mentor
    mentor = create :user
    create :track_mentorship, user: mentor, track: solution.exercise.track
    create :solution_mentorship, solution: solution, user: mentor

    CreatesNotification.expects(:create!).with do |*args|
      assert_equal user, args[0]
      assert_equal :solution_approved, args[1]
      assert_equal "<strong>#{mentor.handle}</strong> has approved your solution to <strong>#{solution.exercise.title}</strong> on the <strong>#{solution.exercise.track.title}</strong> track.", args[2]
      assert_equal "https://test.exercism.io/my/solutions/#{solution.uuid}", args[3]
      assert_equal mentor, args[4][:trigger]
      assert_equal solution, args[4][:about]
    end

    DeliversEmail.expects(:deliver!).with do |*args|
      assert_equal user, args[0]
      assert_equal :solution_approved, args[1]
      assert_equal solution, args[2]
    end

    ApproveSolution.(solution, mentor)
  end

  test "creates solution_mentorship" do
    solution = create :solution
    mentor = create :user
    create :track_mentorship, user: mentor, track: solution.exercise.track

    CreatesSolutionMentorship.expects(:create).with(solution, mentor).returns(mock(update!: false))
    ApproveSolution.(solution, mentor)
  end

  test "cancels a mentor's requires_action when they post" do
    solution = create :solution
    mentor = create :user
    create :track_mentorship, user: mentor, track: solution.exercise.track
    mentorship = create :solution_mentorship, user: mentor, solution: solution, requires_action: true

    ApproveSolution.(solution, mentor)

    mentorship.reload
    refute mentorship.requires_action
  end
end


