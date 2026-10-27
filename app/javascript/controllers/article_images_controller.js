import { Controller } from "@hotwired/stimulus"

// Uploads images dropped or chosen in the article editor to Cloudinary.
// Stops the event before Action Text's Active Storage direct upload runs.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.boundFileAccept = (event) => this.fileAccept(event)
    this.boundAttachmentAdd = (event) => this.attachmentAdd(event)
    document.addEventListener("trix-file-accept", this.boundFileAccept, true)
    document.addEventListener("trix-attachment-add", this.boundAttachmentAdd, true)
    this.element.querySelectorAll("input[type='file']").forEach((input) => {
      input.accept = "image/jpeg,image/png,image/webp,image/gif"
    })
  }

  disconnect() {
    document.removeEventListener("trix-file-accept", this.boundFileAccept, true)
    document.removeEventListener("trix-attachment-add", this.boundAttachmentAdd, true)
  }

  fileAccept(event) {
    if (!this.element.contains(event.target)) return

    const file = event.file
    if (!file) return
    if (this.acceptable(file)) return

    event.preventDefault()
    alert("Use a JPEG, PNG, WebP, or GIF image up to 8 MB.")
  }

  attachmentAdd(event) {
    if (!this.element.contains(event.target)) return

    const attachment = event.attachment
    if (!attachment?.file) return

    event.stopPropagation()
    this.upload(attachment)
  }

  acceptable(file) {
    const type = file.type === "image/jpg" ? "image/jpeg" : file.type
    if (type === "image/svg+xml") return false
    if (type && !type.startsWith("image/")) return false
    return file.size <= 8 * 1024 * 1024
  }

  upload(attachment) {
    const file = attachment.file
    const body = new FormData()
    body.append("image", file)

    const request = new XMLHttpRequest()
    request.open("POST", this.urlValue)
    request.setRequestHeader("Accept", "application/json")
    const token = document.querySelector("meta[name='csrf-token']")?.content
    if (token) request.setRequestHeader("X-CSRF-Token", token)
    request.upload.addEventListener("progress", (event) => {
      if (!event.lengthComputable) return
      attachment.setUploadProgress((event.loaded / event.total) * 90)
    })
    request.addEventListener("load", () => {
      if (request.status >= 200 && request.status < 300) {
        const payload = JSON.parse(request.responseText)
        attachment.setAttributes({
          url: payload.url,
          href: payload.url,
          contentType: file.type || "image",
          width: payload.width,
          height: payload.height
        })
        attachment.setUploadProgress(100)
        return
      }
      this.fail(attachment, this.errorMessage(request))
    })
    request.addEventListener("error", () => this.fail(attachment, "Image upload failed."))
    request.send(body)
  }

  errorMessage(request) {
    try {
      const payload = JSON.parse(request.responseText)
      if (payload.error) return payload.error
    } catch (_error) {
      // The response was not JSON.
    }
    return "Image upload failed."
  }

  fail(attachment, message) {
    attachment.remove()
    alert(message)
  }
}
