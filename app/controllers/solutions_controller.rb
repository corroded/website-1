class SolutionsController < ApplicationController
  before_action :set_solution, except: [:create]

  def create
    exercise = Exercise.find(params[:exercise_id])

    # If this is a side exercise that has no unlocked_by
    # the you can unlock it. This is the only time this method
    # is allowed to be called.
    if !exercise.core && !exercise.unlocked_by
      solution = CreatesSolution.create!(current_user, exercise)
      redirect_to solution
    else
      redirect_to exercise.track
    end
  end

  def show
    @exercise = @solution.exercise
    ClearsNotifications.clear!(current_user, @solution)

    if @solution.iterations.size > 0
      show_started
    else
      show_unlocked
    end
  end

  def confirm_unapproved_completion
    render_modal('solution-confirm-unapproved-completion', "confirm_unapproved_completion")
  end

  def complete
    CompletesSolution.complete!(@solution)
    render_modal("solution-completed", "complete")
  end

  def reflection
    render_modal("solution-reflection", "reflection")
  end

  def reflect
    @solution.update(notes: params[:notes])
    (params[:mentor_reviews] || {}).each do |mentor_id, data|
      ReviewsSolutionMentoring.review!(
        @solution,
        User.find(mentor_id),
        data[:rating],
        data[:feedback]
      )
    end
    render_modal("solution-unlocked", "unlocked")
  end

  private
  def set_solution
    @solution = current_user.solutions.find(params[:id])
  end

  def show_unlocked
    render :show_unlocked
  end

  def show_started
    @iteration = @solution.iterations.find_by_id(params[:iteration_id]) || @solution.iterations.first
    @track = @solution.exercise.track
    @user_track = UserTrack.where(user: current_user, track: @track).first

    # TODO
    # If @iteration is null then the following page will break
    # so we need to guard. However, it means that the solution is
    # in the wrong state in the first place. Does this mean the
    # state machine approach is wrong (to be able to allow this)
    # or something else?

    render :show_started
  end
end
