# frozen_string_literal: true

# Credentials come from CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and
# CLOUDINARY_API_SECRET. The gem reads those on first use. Delivery URLs are
# always https so brochure sites can embed them.
Cloudinary.config.secure = true
