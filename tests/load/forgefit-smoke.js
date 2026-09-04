import http from 'k6/http';
import { check, sleep } from 'k6';

const base=(__ENV.FORGEFIT_BASE_URL||'https://forgefityou.com').replace(/\/$/,'');
const pages=['/','/auth','/find-professional','/marketplace','/gym-culture','/community-feed'];

export const options={
  stages:[
    {duration:'30s',target:10},
    {duration:'1m',target:25},
    {duration:'1m',target:50},
    {duration:'30s',target:0}
  ],
  thresholds:{
    http_req_failed:['rate<0.01'],
    http_req_duration:['p(95)<2000','p(99)<4000']
  }
};

export default function(){
  const path=pages[Math.floor(Math.random()*pages.length)];
  const response=http.get(base+path,{tags:{page:path}});
  check(response,{
    'page returned successfully':r=>r.status>=200&&r.status<400,
    'page has content':r=>r.body&&r.body.length>500
  });
  sleep(Math.random()*2+1);
}
