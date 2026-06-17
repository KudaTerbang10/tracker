# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# communication
- Respond in Indonesian (Bahasa Indonesia) when interacting with this user. Confidence: 0.80

# search
- For user management search: Search by name and cabang name only, not by email. Confidence: 0.70

# windows
- For Windows builds: Use manual text input for nomor resi and let users leverage USB barcode scanner devices, rather than attempting camera-based scanning. Confidence: 0.75

# mongodb
- Use GeoJSON format (Point type with [longitude, latitude] coordinates) for MongoDB geospatial data to enable future geospatial queries. Confidence: 0.70

# flutter
See [flutter/taste.md](flutter/taste.md)

# driver-query
- For the driver history (Riwayat) tab: Query by `tracking_logs[].driver_ditugaskan.user_id` but EXCLUDE transactions where `driver_user_id = current driver AND status_saat_ini = 'proses_kirim'` (those belong in the Perlu Dikirim tab instead). This lets drivers see historical assignments (e.g., Budi who completed his leg) while preventing current active tasks (e.g., Hendra still delivering) from appearing in both tabs. Confidence: 0.80
- For the driver current (Perlu Dikirim) tab's orange count badge: Query only by `driver_user_id` (active tasks only), NOT by tracking_logs — the badge should show tasks currently assigned to this driver, not historical assignments. Confidence: 0.80
- A transaction should appear in only ONE tab for a given driver — either Perlu Dikirim (if `driver_user_id = this driver AND status_saat_ini = 'proses_kirim'`) or Riwayat (if historically handled via tracking_logs and not currently active for this driver). Confidence: 0.85
- For "scan barang diterima" (receive scan), validate server-side that the requesting driver's `_id` matches the transaction's `driver_user_id` — prevent drivers who only appear in `tracking_logs[].driver_ditugaskan` history from scanning/updating the transaction. Confidence: 0.85

# domain
- Multiple drivers can be assigned to the same package sequentially across different legs of its journey (e.g., Driver A from gudang A → gudang B, Driver B from gudang B → penerima). The top-level `driver_user_id` always reflects only the **current** assigned driver, while `tracking_logs[].driver_ditugaskan` stores the history of all drivers who handled it. Confidence: 0.80
- Users refer to the orange count badge on the "Perlu Dikirim" tab as the "task icon banner" — it shows the count of delivery tasks. Confidence: 0.90

# phone-formatting
- For phone numbers starting with "08" in form displays: Format with dash (-) every 4 digits for readability (e.g., 0812-3456-7890), but only in the UI — store raw digits without formatting in the database. Confidence: 0.70

# layout
- For hero sections with carousel: The carousel should span full screen width left-to-right, with hero content (logo, text, buttons, tracking card) overlaying on top of it rather than being beside or below it. Confidence: 0.70
