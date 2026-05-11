# Domain 7: MCP & External Integration

**Available MCP Tools**:

| MCP | Capabilities | Key Use |
|-----|-------------|---------|
| Playwright | navigate, click, fill, screenshot, evaluate JS | Browser automation |
| Memory | create/read/search entities and relations | Persistent knowledge storage |
| Context7 | resolve-library-id, query-docs | Documentation lookup |
| WebFetch | Fetch URL content | Alternative network channel |
| Schedule | Create/update cron tasks | Automated recurring tasks |

**MCP Combination Patterns**:
- Playwright + Memory: Scrape web data → store in knowledge graph
- Context7 + Playwright: Look up docs → test code in browser
- WebFetch + Node.js: Fetch content → process with scripts
- Schedule + Memory: Periodic data collection → persistent storage

**Chrome DevTools Protocol**: Accessible on port 9222 when browser is running. Test with:
```bash
node -e "const http=require('http');http.get('http://127.0.0.1:9222/json/version',r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>console.log(d))}).on('error',e=>console.log('FAIL'))"
```
