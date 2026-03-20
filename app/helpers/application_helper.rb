# frozen_string_literal: true

module ApplicationHelper
  def input_classes
    "block w-full max-w-full rounded-lg border border-zinc-600 bg-zinc-900/80 px-3 py-2.5 text-base text-zinc-100 placeholder:text-zinc-500 shadow-sm focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 sm:py-2 sm:text-sm"
  end

  def label_classes
    "mb-1 block text-sm font-medium text-zinc-300"
  end

  def primary_button_classes
    "inline-flex min-h-11 w-full items-center justify-center rounded-lg bg-emerald-600 px-4 py-2 text-sm font-semibold text-zinc-950 shadow-sm transition hover:bg-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:ring-offset-2 focus:ring-offset-zinc-950 touch-manipulation sm:min-h-0 sm:w-auto"
  end

  def secondary_button_classes
    "inline-flex min-h-11 w-full items-center justify-center rounded-lg border border-zinc-600 bg-zinc-800/80 px-4 py-2 text-sm font-medium text-zinc-200 transition hover:border-zinc-500 hover:bg-zinc-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:ring-offset-2 focus:ring-offset-zinc-950 touch-manipulation sm:min-h-0 sm:w-auto"
  end

  def danger_button_classes
    "inline-flex min-h-11 w-full items-center justify-center rounded-lg border border-red-900/60 bg-red-950/40 px-4 py-2 text-sm font-medium text-red-300 transition hover:bg-red-950/70 focus:outline-none focus:ring-2 focus:ring-red-500/40 focus:ring-offset-2 focus:ring-offset-zinc-950 touch-manipulation sm:min-h-0 sm:w-auto"
  end

  def nav_item_classes(active)
    base = "flex min-h-11 items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors touch-manipulation sm:min-h-0"
    if active
      "#{base} bg-emerald-500/15 text-emerald-400 ring-1 ring-emerald-500/25"
    else
      "#{base} text-zinc-400 hover:bg-zinc-800/80 hover:text-zinc-100"
    end
  end

  def sidebar_selected_website_id
    params[:website_id].presence || (controller_name == "websites" && action_name != "index" && action_name != "new" ? params[:id] : nil)
  end

  def website_nav_active?(website_record)
    return false unless website_record.persisted?

    params[:website_id].to_s == website_record.id.to_s ||
      (controller_name == "websites" && params[:id].to_s == website_record.id.to_s)
  end

  def show_website_content_nav?
    @website&.persisted? && (
      params[:website_id].present? ||
        (controller_name == "websites" && %w[show edit update].include?(action_name))
    )
  end

  def content_section_card_classes
    "rounded-xl border border-zinc-800 bg-zinc-900/50 p-4 shadow-lg shadow-black/20 sm:p-6"
  end

  def form_footer_actions_classes
    "flex flex-col-reverse gap-3 sm:flex-row sm:flex-wrap"
  end
end
