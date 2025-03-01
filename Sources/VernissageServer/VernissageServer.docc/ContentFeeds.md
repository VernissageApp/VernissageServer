# Content feeds (RSS/Atom)

**RSS** (Really Simple Syndication) and **Atom** are widely used web feed formats that allow users to subscribe to updates from websites in an organized and automated way. These protocols enable seamless content consumption through feed readers, making it easier to stay up to date with new posts, images, and other shared content without manually visiting a website.

Vernissage fully supports both **RSS** and **Atom**, allowing users to browse various timelines and individual user profiles through compatible feed readers. Each feed provides structured data on the latest activity, ensuring that users can stay engaged with their favorite content effortlessly. Vernissage offers multiple RSS/Atom endpoints, making it possible to follow specific timelines or curated content easily. The available RSS feeds include:

- **User's feeds**: `/(rss|atom)/users/@{username}` - follow updates from a specific user.
- **Local timeline**: `/(rss|atom)/local` - see posts from users within the local instance.
- **Global timeline**: `/(rss|atom)/global` - discover content from across the Fediverse network.
- **Trending posts**:
  - `/(rss|atom)/trending/daily` - most popular posts of the day.
  - `/(rss|atom)/trending/monthly` - most popular posts of the month.
  - `/(rss|atom)/trending/yearly` - most popular posts of the year.
- **Featured posts**: `/(rss|atom)/featured` - a selection of highlighted content.
- **Category feeds**: `/(rss|atom)/categories/{category}` - follow posts from a specific category.
- **Hashtag feeds**: `/(rss|atom)/hashtags/{hashtag}` – stay updated on content using a specific hashtag.

Each Atom/RSS feeds provides up to 40 recent posts, ensuring users have access to the latest content. The only difference between RSS and Atom feed URLs is the prefix: RSS feeds use `/rss/`, while Atom feeds use `/atom/`.
