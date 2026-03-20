import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this._onKeydown = this._onKeydown.bind(this)
    this._onResize = () => {
      if (window.innerWidth >= 1024) this.close()
    }
    this._onTurboVisit = () => this.close()
    window.addEventListener("resize", this._onResize)
    document.addEventListener("turbo:before-visit", this._onTurboVisit)
    this.close()
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
    document.removeEventListener("turbo:before-visit", this._onTurboVisit)
    document.removeEventListener("keydown", this._onKeydown)
    this._unlockScroll()
  }

  open() {
    if (window.innerWidth >= 1024) return

    this.panelTarget.classList.remove("-translate-x-full")
    this.panelTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.add("opacity-100")
    this._lockScroll()
    document.addEventListener("keydown", this._onKeydown)
  }

  close() {
    document.removeEventListener("keydown", this._onKeydown)
    this._unlockScroll()
    this.backdropTarget.classList.add("opacity-0", "pointer-events-none")
    this.backdropTarget.classList.remove("opacity-100")
    this.panelTarget.classList.remove("translate-x-0")
    if (window.innerWidth >= 1024) return

    this.panelTarget.classList.add("-translate-x-full")
  }

  toggle() {
    if (window.innerWidth >= 1024) return

    if (this.panelTarget.classList.contains("translate-x-0")) {
      this.close()
    } else {
      this.open()
    }
  }

  _onKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  _lockScroll() {
    if (window.innerWidth >= 1024) return

    document.documentElement.classList.add("overflow-hidden")
  }

  _unlockScroll() {
    document.documentElement.classList.remove("overflow-hidden")
  }
}
