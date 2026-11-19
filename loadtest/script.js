// Load profile "few writes, many reads" for the Blog API.
//
// One iteration of one virtual user (VU) = 1 write + 9 reads:
//   POST /posts                      create a post
//   GET  /posts?limit=20      x3     first page of the list (the hottest read)
//   GET  /posts?offset=20     x1     second page
//   GET  /posts/{new id}      x2     the post we just created
//   GET  /posts/{older id}    x1     some older post
//   GET  /authors/{id}        x2     author data
// then the user "thinks" for THINK_TIME seconds and starts again.
//
// Phases: ramp 0 -> VUS in RAMP, hold VUS for STEADY, ramp down to 0 in DOWN.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';

const BASE_URL = __ENV.BASE_URL;
const VUS = Number(__ENV.VUS || 30);
const RAMP = __ENV.RAMP || '3m';
const STEADY = __ENV.STEADY || '5m';
const DOWN = __ENV.DOWN || '2m';
const THINK_TIME = Number(__ENV.THINK_TIME || 1);
const LABEL = __ENV.LABEL || 'run';

const JSON_HEADERS = { 'Content-Type': 'application/json' };

// Names group URLs with different ids into one line of the report.
const ENDPOINTS = ['POST /posts', 'GET /posts', 'GET /posts/{id}', 'GET /authors/{id}'];

export const options = {
  scenarios: {
    blog_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: RAMP, target: VUS },
        { duration: STEADY, target: VUS },
        { duration: DOWN, target: 0 },
      ],
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'], // less than 1% errors
    // Per-endpoint thresholds are loose on purpose: they make k6 report
    // latency separately for every endpoint.
    ...Object.fromEntries(ENDPOINTS.map((name) => [`http_req_duration{name:${name}}`, ['p(95)<5000']])),
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

export function setup() {
  if (!BASE_URL) throw new Error('BASE_URL is not set');
  // A few authors so that writes are spread between them.
  const authors = [];
  for (let i = 0; i < 10; i++) {
    const res = http.post(
      `${BASE_URL}/authors`,
      JSON.stringify({ name: `Load User ${i}`, email: `load-${Date.now()}-${i}@example.com` }),
      { headers: JSON_HEADERS },
    );
    check(res, { 'author created': (r) => r.status === 201 });
    authors.push(res.json('id'));
  }
  return { authors };
}

function get(path, name) {
  const res = http.get(`${BASE_URL}${path}`, { tags: { name } });
  check(res, { [`${name} 200`]: (r) => r.status === 200 });
  return res;
}

export default function (data) {
  const authorId = data.authors[(__VU - 1) % data.authors.length];

  // 1 write
  const created = http.post(
    `${BASE_URL}/posts`,
    JSON.stringify({
      title: `Post from VU ${__VU}, iteration ${__ITER}`,
      content: 'Load test post. '.repeat(10),
      author_id: authorId,
    }),
    { headers: JSON_HEADERS, tags: { name: 'POST /posts' } },
  );
  const ok = check(created, { 'POST /posts 201': (r) => r.status === 201 });
  const newId = ok ? created.json('id') : 1;
  const olderId = Math.max(1, newId - 1 - Math.floor(Math.random() * 500));

  // 9 reads
  get('/posts?limit=20', 'GET /posts');
  get(`/posts/${newId}`, 'GET /posts/{id}');
  get(`/authors/${authorId}`, 'GET /authors/{id}');
  get('/posts?limit=20', 'GET /posts');
  get(`/posts/${olderId}`, 'GET /posts/{id}');
  get('/posts?limit=20&offset=20', 'GET /posts');
  get(`/posts/${newId}`, 'GET /posts/{id}');
  get('/posts?limit=20', 'GET /posts');
  get(`/authors/${authorId}`, 'GET /authors/{id}');

  sleep(THINK_TIME);
}

export function handleSummary(data) {
  return {
    stdout: textSummary(data, { indent: '  ', enableColors: true }),
    [`results/${LABEL}-summary.json`]: JSON.stringify(data, null, 2),
  };
}
