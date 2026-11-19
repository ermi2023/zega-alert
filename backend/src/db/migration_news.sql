-- News & Road Closures enhancements
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS source_label VARCHAR(100) DEFAULT 'EthioShield News';
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS badge_label VARCHAR(50);
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS badge_color VARCHAR(30);

-- Road closure support with coordinates and timings
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS closure_start_lat DOUBLE PRECISION;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS closure_start_lng DOUBLE PRECISION;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS closure_end_lat DOUBLE PRECISION;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS closure_end_lng DOUBLE PRECISION;
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS start_time_label VARCHAR(50);
ALTER TABLE announcements ADD COLUMN IF NOT EXISTS detour_info VARCHAR(150);

-- Likes and Dislikes support (updating post_likes to support like vs dislike reaction)
ALTER TABLE post_likes ADD COLUMN IF NOT EXISTS reaction VARCHAR(10) DEFAULT 'like'; -- 'like' or 'dislike'
