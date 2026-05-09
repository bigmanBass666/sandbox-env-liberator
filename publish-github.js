#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const TOKEN = process.env.GITHUB_PERSONAL_ACCESS_TOKEN;
if (!TOKEN) {
    console.error('Error: No GitHub token found in environment');
    process.exit(1);
}

// Helper function to make GitHub API requests
async function githubApi(method, endpoint, body = null) {
    const options = {
        method: method,
        headers: {
            'Authorization': `Bearer ${TOKEN}`,
            'Accept': 'application/vnd.github.v3+json',
            'Content-Type': 'application/json',
            'User-Agent': 'sandbox-env-liberator',
        },
        signal: AbortSignal.timeout(30000),
    };

    if (body) {
        options.body = JSON.stringify(body);
    }

    const url = `https://api.github.com${endpoint}`;
    console.log(`Calling GitHub API: ${method} ${url}`);
    
    const response = await fetch(url, options);
    const data = await response.json();
    
    if (!response.ok) {
        throw new Error(`GitHub API error (${response.status}): ${JSON.stringify(data)}`);
    }
    return data;
}

async function main() {
    console.log('=== Sandbox Env Setup GitHub Upload ===\n');
    
    // 1. Create repository
    const repoName = 'sandbox-env-liberator';
    console.log(`Creating repository: ${repoName}`);
    try {
        const repo = await githubApi('POST', '/user/repos', {
            name: repoName,
            description: 'Cloud sandbox environment liberation and development setup system',
            private: false,
            auto_init: false,
            has_issues: true,
            has_wiki: true,
        });
        console.log(`✅ Repository created successfully: ${repo.html_url}`);
        
        // 2. Initialize local git repo
        const workDir = '/workspace/sandbox-env-setup';
        console.log(`\nInitializing local Git repository in ${workDir}`);
        process.chdir(workDir);
        
        try {
            execSync('git init', { stdio: 'pipe' });
            execSync('git config --local user.name "Sandbox Env Liberator"', { stdio: 'pipe' });
            execSync('git config --local user.email "liberator@sandbox.local"', { stdio: 'pipe' });
            execSync('git add .', { stdio: 'pipe' });
            execSync('git commit -m "Initial commit: full sandbox environment liberation system"', { stdio: 'pipe' });
            execSync(`git remote add origin https://x-access-token:${TOKEN}@github.com/$(git config --global user.name 2>/dev/null || echo "sandbox-liberator")/${repoName}.git`, { stdio: 'pipe' });
            console.log('✅ Git repository initialized and committed');
        } catch (e) {
            // Repo might already be initialized, that's fine
            console.log('⚠️  Git repo already initialized');
        }
        
        // 3. Get current user to get username
        console.log('\nGetting GitHub user info...');
        const user = await githubApi('GET', '/user');
        console.log(`✅ User: ${user.login} (${user.name || user.login})`);
        
        // 4. Set the correct remote with username
        const remoteUrl = `https://x-access-token:${TOKEN}@github.com/${user.login}/${repoName}.git`;
        console.log(`Setting remote origin to: ${remoteUrl}`);
        try {
            execSync('git remote remove origin 2>/dev/null', { stdio: 'pipe' });
        } catch {}
        execSync(`git remote add origin ${remoteUrl}`, { stdio: 'pipe' });
        
        // 5. Push to main branch
        console.log('\nPushing code to GitHub...');
        try {
            execSync('git branch -M main', { stdio: 'pipe' });
            execSync('git push -u origin main --force', { stdio: 'pipe' });
            console.log('✅ Code pushed successfully!');
        } catch (e) {
            console.error('❌ Push failed:', e.stderr?.toString() || e.message);
            // Fallback: try to pull and re-push
            console.log('Attempting to pull and re-push...');
            try {
                execSync('git pull origin main --allow-unrelated-histories 2>/dev/null || true', { stdio: 'pipe' });
                execSync('git push -u origin main', { stdio: 'pipe' });
                console.log('✅ Code pushed successfully!');
            } catch (e2) {
                console.error('❌ Fallback push also failed:', e2.stderr?.toString() || e2.message);
            }
        }
        
        // 6. Show final URL
        console.log('\n' + '='.repeat(60));
        console.log(`🎉 Repository created at: https://github.com/${user.login}/${repoName}`);
        console.log('='.repeat(60));
        
    } catch (e) {
        console.error('❌ Error:', e.message);
        // Check if repo already exists
        if (e.message.includes('already exists')) {
            console.log('\n⚠️  Repository already exists, trying to update...');
            // Try to get user and update
            try {
                const user = await githubApi('GET', '/user');
                console.log(`Using existing repo: https://github.com/${user.login}/${repoName}`);
                
                // Initialize git and push
                const workDir = '/workspace/sandbox-env-setup';
                process.chdir(workDir);
                
                try { execSync('git init -q', { stdio: 'pipe' }); } catch {}
                try { execSync('git config --local user.name "Sandbox Env Liberator"', { stdio: 'pipe' }); } catch {}
                try { execSync('git config --local user.email "liberator@sandbox.local"', { stdio: 'pipe' }); } catch {}
                try { execSync('git add .', { stdio: 'pipe' }); } catch {}
                try { execSync('git commit -m "Update: sandbox environment liberation system" -q 2>/dev/null || git commit -m "Initial commit" -q 2>/dev/null', { stdio: 'pipe' }); } catch {}
                
                const remoteUrl = `https://x-access-token:${TOKEN}@github.com/${user.login}/${repoName}.git`;
                try { execSync('git remote remove origin 2>/dev/null', { stdio: 'pipe' }); } catch {}
                try { execSync(`git remote add origin ${remoteUrl}`, { stdio: 'pipe' }); } catch {}
                
                try {
                    execSync('git branch -M main', { stdio: 'pipe' });
                    execSync('git push -u origin main --force', { stdio: 'pipe' });
                    console.log('✅ Code pushed successfully to existing repo!');
                    console.log(`\n📦 Repository: https://github.com/${user.login}/${repoName}`);
                } catch (e2) {
                    console.error('❌ Push failed:', e2.stderr?.toString() || e2.message);
                }
            } catch (e3) {
                console.error('❌ Could not handle existing repo:', e3.message);
            }
        } else {
            process.exit(1);
        }
    }
}

main()
    .then(() => console.log('\nDone!'))
    .catch(err => { console.error('Fatal:', err); process.exit(1); });
