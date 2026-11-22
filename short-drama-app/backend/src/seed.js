'use strict';
const { all, get, run, tx } = require('./db');
const { uid } = require('./auth');
const captions = require('./captions');
const UNLOCK_COST = parseInt(process.env.EPISODE_UNLOCK_COIN_COST || '30', 10);
const VIDEOS = [
  'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
];
// Mirrors settings.js CHECKIN_DEFAULT (rebalanced 2026-11-22, CODE_READINESS item 4)
const CHECKIN = [10, 20, 15, 15, 20, 10, 30];
const GENRES = [
  ['genre-romance', 'romance', 'Romance', 'Love stories that melt hearts', '#E63A6E'],
  ['genre-revenge', 'revenge', 'Revenge', 'Sweet payback, served cold', '#B71C1C'],
  ['genre-ceo', 'ceo-billionaire', 'CEO / Billionaire', 'Power, wealth and desire', '#6A1B9A'],
  ['genre-urban', 'urban', 'Urban', 'City life, real stakes', '#1565C0'],
  ['genre-fantasy', 'fantasy', 'Fantasy', 'Magic, fate and other worlds', '#00838F'],
  ['genre-suspense', 'suspense', 'Suspense', 'Twists you will not see coming', '#37474F'],
  ['genre-werewolf', 'werewolf', 'Werewolf', 'Fated mates and full moons', '#4E342E'],
];
// slug,title,genreId,year,flags,views,likes,rating,rank,tags,gradients
const SERIES = [
  ['married-to-the-ceo', 'Married to the CEO', 'genre-ceo', 2025, { hot: 1, featured: 1, exclusive: 1 }, 4821000, 231000, 4.8, 98, ['ceo', 'contract-marriage', 'sweet'], '#311B92', '#E63A6E'],
  ['revenge-of-the-heiress', 'Revenge of the Heiress', 'genre-revenge', 2025, { hot: 1, featured: 1, new: 1 }, 3912000, 198000, 4.7, 95, ['revenge', 'heiress', 'face-slap'], '#B71C1C', '#FF8A65'],
  ['my-secret-husband', 'My Secret Husband', 'genre-romance', 2024, { hot: 1 }, 2874000, 154000, 4.6, 88, ['romance', 'hidden-identity'], '#AD1457', '#FF80AB'],
  ['alpha-fated-mate', 'The Alpha\u2019s Fated Mate', 'genre-werewolf', 2025, { new: 1, featured: 1, dubbed: 1 }, 2145000, 121000, 4.5, 85, ['werewolf', 'fated-mate'], '#4E342E', '#FFB300'],
  ['city-of-hidden-lies', 'City of Hidden Lies', 'genre-urban', 2024, {}, 1320000, 67000, 4.4, 72, ['urban', 'mystery'], '#1565C0', '#4FC3F7'],
  ['the-last-signal', 'The Last Signal', 'genre-suspense', 2025, { new: 1, hot: 1 }, 1987000, 99000, 4.6, 90, ['suspense', 'thriller'], '#263238', '#78909C'],
  ['reborn-as-the-villainess', 'Reborn as the Villainess', 'genre-fantasy', 2025, { new: 1 }, 1654000, 88000, 4.5, 80, ['fantasy', 'rebirth'], '#00695C', '#80CBC4'],
  ['vip-empire-of-desire', 'Empire of Desire', 'genre-ceo', 2025, { vip: 1, exclusive: 1, featured: 1 }, 3210000, 176000, 4.9, 97, ['ceo', 'vip'], '#4A148C', '#EA80FC'],
];
const CAST = [
  ['person-li-wei', 'li-wei', 'Li Wei', 'male'], ['person-chen-xiao', 'chen-xiao', 'Chen Xiao', 'female'],
  ['person-wang-hao', 'wang-hao', 'Wang Hao', 'male'], ['person-liu-yan', 'liu-yan', 'Liu Yan', 'female'],
  ['person-zhang-min', 'zhang-min', 'Zhang Min', 'female'], ['person-zhao-lei', 'zhao-lei', 'Zhao Lei', 'male'],
];
// Coin values rebalanced 2026-11-22 (CODE_READINESS item 4): one-shot
// starter tasks paid 140 unverified coins on day 1; they now pay a token
// amount, and milestone tasks scale with real effort.
const TASKS = [
  ['connect_email', 'Connect your email', 'Link an email to secure your account', 5, 'connect_email', 1, 1],
  ['rate_app', 'Rate HERO DRAMA', 'Leave a rating in the store', 5, 'rate_app', 2, 1],
  ['invite_friend', 'Invite a friend', 'Share HERO DRAMA with a friend', 10, 'invite_friend', 3, 1],
  ['enable_notifications', 'Turn on notifications', 'Never miss a new episode', 5, 'enable_notifications', 4, 1],
  ['series_watch_3', 'Watch 3 dramas', 'Start 3 different series', 15, 'watch_episodes', 10, 3],
  ['series_watch_10', 'Watch 10 dramas', 'Start 10 different series', 40, 'watch_episodes', 11, 10],
  ['series_watch_25', 'Watch 25 dramas', 'Start 25 different series', 100, 'watch_episodes', 12, 25],
  ['series_collect_5', 'Collect 5 dramas', 'Add 5 series to My List', 20, 'collect_series', 13, 5],
];
const MISSIONS = [
  // slug, title, description, metric, target, coins, sortOrder
  ['watch_3_episodes', 'Watch 3 episodes', 'Watch 3 different episodes today', 'watch_episodes', 3, 20, 1],
  ['watch_15_minutes', 'Watch 15 minutes', 'Watch for 15 minutes today', 'watch_minutes', 15, 5, 2],
  ['like_3_series', 'Like 3 series', 'Like 3 series today', 'likes', 3, 5, 3],
  ['share_1_series', 'Share a series', 'Share a series today', 'shares', 1, 5, 4],
  ['daily_checkin', 'Daily check-in', 'Check in today', 'checkin', 1, 10, 5],
];
function seedMissions() {
  // Seed missions only if the missions table is empty.
  if (get('SELECT COUNT(*) c FROM missions').c > 0) return;
  MISSIONS.forEach((ms) => run('INSERT INTO missions(slug,title,description,metric,target,coins,sortOrder,active) VALUES(?,?,?,?,?,?,?,1)', ...ms));
}
function seed() {
  // Crash-safety: the whole seed (including the 'seeded' flag, written last)
  // runs in ONE transaction — a crash mid-seed rolls everything back instead
  // of leaving partial rows that would make the next boot's seed throw.
  tx(() => seedInner());
}
function seedInner() {
  seedMissions();
  if (get("SELECT value FROM meta WHERE key='seeded'")) return;
  const now = new Date().toISOString();
  GENRES.forEach((g, i) => run('INSERT INTO genres(id,slug,name,description,colorHex,sortOrder) VALUES(?,?,?,?,?,?)', g[0], g[1], g[2], g[3], g[4], i + 1));
  CAST.forEach((p) => run('INSERT INTO persons(id,slug,name,gender,imageUrl) VALUES(?,?,?,?,?)', p[0], p[1], p[2], p[3], `https://picsum.photos/seed/${p[1]}/200/200`));
  SERIES.forEach((s, si) => {
    const [slug, title, genreId, year, f, views, likes, rating, rank, tags, gs, ge] = s;
    const id = 'series-' + slug;
    const epCount = 10;
    run(`INSERT INTO series(id,slug,title,synopsis,tagline,coverImageUrl,heroImageUrl,trailerUrl,gradientStart,gradientEnd,genreId,releaseYear,totalEpisodes,totalSeasons,language,dubLanguages,isVipOnly,isExclusive,isNew,isHot,isCompleted,isDubbed,viewCount,likeCount,ratingAvg,ratingCount,rankScore,isFeatured,sortOrder,tags,createdAt)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      id, slug, title, `${title} — a binge-worthy short drama full of twists, romance and cliffhangers in every 2-minute episode.`,
      'You cannot stop at one episode', `https://picsum.photos/seed/${slug}/600/800`, `https://picsum.photos/seed/${slug}-hero/1200/675`,
      VIDEOS[si % VIDEOS.length], gs, ge, genreId, year, epCount, 1, 'en',
      f.dubbed ? JSON.stringify(['es', 'pt']) : '[]', f.vip ? 1 : 0, f.exclusive ? 1 : 0, f.new ? 1 : 0, f.hot ? 1 : 0, 1,
      f.dubbed ? 1 : 0, views, likes, rating, Math.round(likes / 3), rank, f.featured ? 1 : 0, si + 1, JSON.stringify(tags), now);
    const seasonId = id + '-s1';
    run('INSERT INTO seasons(id,seriesId,seasonNumber,title,episodeCount) VALUES(?,?,?,?,?)', seasonId, id, 1, 'Season 1', epCount);
    for (let n = 1; n <= epCount; n++) {
      const epId = `${id}-ep${n}`;
      const isFree = n <= 2;
      run(`INSERT INTO episodes(id,seriesId,seasonId,seasonNumber,episodeNumber,title,description,videoUrl,thumbnailUrl,durationSeconds,isFree,coinCost,isVipOnly,publishedAt,viewCount,sortOrder)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        epId, id, seasonId, 1, n, `Episode ${n}`, `Episode ${n} of ${title}.`, VIDEOS[(si + n - 1) % VIDEOS.length],
        `https://picsum.photos/seed/${slug}-ep${n}/600/800`, 90 + n * 7, isFree ? 1 : 0, isFree ? 0 : UNLOCK_COST, f.vip ? 1 : 0, now, Math.round(views / epCount), n);
      if (f.dubbed) {
        run('INSERT INTO episode_dubs(id,episodeId,lang,videoUrl) VALUES(?,?,?,?)', uid(), epId, 'es', VIDEOS[(si + n) % VIDEOS.length]);
        run('INSERT INTO episode_dubs(id,episodeId,lang,videoUrl) VALUES(?,?,?,?)', uid(), epId, 'pt', VIDEOS[(si + n + 1) % VIDEOS.length]);
      }
    }
    // 2 cast members per series (rotating)
    [0, 1].forEach((k) => {
      const p = CAST[(si * 2 + k) % CAST.length];
      run('INSERT INTO cast_members(id,seriesId,personId,characterName,sortOrder) VALUES(?,?,?,?,?)', uid(), id, p[0], k === 0 ? 'Lead' : 'Co-lead', k + 1);
    });
  });
  const sections = [
    ['sec-hero', 'featured-hero', 'Featured', 'Top picks for you', 'featured_hero', ['series-married-to-the-ceo', 'series-vip-empire-of-desire', 'series-alpha-fated-mate']],
    ['sec-trending', 'trending-now', 'Trending Now', 'What everyone is watching', 'series_carousel', ['series-married-to-the-ceo', 'series-revenge-of-the-heiress', 'series-my-secret-husband', 'series-the-last-signal']],
    ['sec-ranking', 'top-ranking', 'Top Ranking', 'Ranked by fans', 'ranking_list', ['series-married-to-the-ceo', 'series-vip-empire-of-desire', 'series-revenge-of-the-heiress', 'series-the-last-signal', 'series-my-secret-husband']],
    ['sec-new', 'new-releases', 'New Releases', 'Fresh this week', 'new_releases', ['series-revenge-of-the-heiress', 'series-alpha-fated-mate', 'series-the-last-signal', 'series-reborn-as-the-villainess']],
    ['sec-hot', 'hot-grid', 'Hot Right Now', null, 'hot_grid', ['series-married-to-the-ceo', 'series-revenge-of-the-heiress', 'series-my-secret-husband', 'series-the-last-signal']],
    ['sec-all', 'all-dramas', 'All Dramas', 'Browse the full library', 'vertical_grid', SERIES.map((s) => 'series-' + s[0])],
    ['sec-genres', 'browse-genres', 'Browse by Genre', null, 'genre_grid', SERIES.map((s) => 'series-' + s[0])],
  ];
  sections.forEach((sec, i) => {
    run('INSERT INTO home_sections(id,slug,title,subtitle,sectionType,sortOrder) VALUES(?,?,?,?,?,?)', sec[0], sec[1], sec[2], sec[3], sec[4], i + 1);
    sec[5].forEach((sid, j) => run('INSERT INTO home_section_items(sectionId,seriesId,sortOrder) VALUES(?,?,?)', sec[0], sid, j + 1));
  });
  TASKS.forEach((t) => run('INSERT INTO reward_tasks(slug,title,description,coins,actionType,sortOrder,target) VALUES(?,?,?,?,?,?,?)', ...t));
  // Phase 2 captions seed: run the demo pipeline synchronously for the first 2
  // episodes of the first series so ready orig+ar+en tracks exist out of the box.
  const firstSeriesId = 'series-' + SERIES[0][0];
  [1, 2].forEach((n) => captions.generateDemoTracksSync(`${firstSeriesId}-ep${n}`));
  run("INSERT INTO meta(key,value) VALUES('seeded','1')");
  console.log(`[seed] genres=${GENRES.length} series=${SERIES.length} episodes=${SERIES.length * 10} tasks=${TASKS.length} checkin=${CHECKIN.join(',')}`);
}
module.exports = { seed, CHECKIN, VIDEOS };
