hello-server

A small FastAPI app that I deployed to a real cloud server (AWS EC2) by hand, to learn how deployment actually works: SSH, firewalls, Linux services, and shipping changes safely through pull requests.

What it does
Endpoint Returns
GET / {"message": "hello from philip's server"}
GET /health {"status": "ok"} (used to check the app is alive)
GET /version {"version": "1.0"} (used to confirm a deploy went out)
How it works (the big picture)
git push / PR
git pull
My Mac(write code)
GitHub(stores code)
AWS EC2 server(runs code)
systemd(keeps app running)
uvicorn + FastAPIport 8000
My Mac is where I write code and open pull requests.
GitHub stores the code. Only code merged into main gets deployed.
The EC2 server is a small Linux computer I rent from AWS (Ubuntu, t3.micro). It pulls the latest code from GitHub and runs it.
systemd (Linux's service manager) keeps the app running: it restarts it if it crashes, starts it when the server reboots, and keeps it alive after I disconnect.
Security setup

Two separate locks protect the server:

Firewall (AWS security group): only my own IP address can reach the server. Port 22 (SSH) and port 8000 (the app) are open to my IP only (/32 = exactly one address). Everyone else is blocked before reaching the server.
SSH key: logging in requires my private key, which never leaves my Mac. The server only stores my public key, in ~/.ssh/authorized_keys. Password logins are off.

If one lock ever failed, the other would still protect the server.

Run it locally
bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload

Then open http://localhost:8000/health, or http://localhost:8000/docs for FastAPI's interactive API page.

Deploy

Every change goes through a pull request. Once it's merged into main, I deploy with one command from my Mac:

bash
ssh hello '~/hello-server/deploy.sh'

(hello is a shortcut in my ~/.ssh/config for the server's address and username.)

deploy.sh runs on the server and:

Pulls the latest main from GitHub
Installs any new packages from requirements.txt
Restarts the app so the new code is loaded
Checks /health, and stops with an error if the app isn't healthy
Problems I hit (and how I fixed them)

SSH just hung forever with no error. When SSH hangs with no output, the firewall is blocking you. I checked my real IP with curl -4 ifconfig.me, and it didn't match the IP in the AWS security group. The cause was iCloud Private Relay in Safari: when I clicked AWS's "My IP" button, it saw Apple's relay address instead of mine. My terminal doesn't go through the relay, so SSH came from my real IP. Fix: I typed my real IP followed by /32 into the rule by hand.

curl ifconfig.me showed a weird long address. That was my IPv6 address. My SSH connection used IPv4, so I needed curl -4 ifconfig.me to see the address the firewall actually checks.

AWS rejected my SSH public key ("not valid OpenSSH format"). My key file was fine (it starts with ssh-ed25519), but the copy-paste kept going wrong. Uploading the .pub file directly with the Browse button worked.

My app died overnight. I had started the app inside my SSH session. When my Mac slept, the connection dropped ("Broken pipe"), and the app died with it. Fix: I made the app a systemd service, so it runs independently of my terminal, restarts on crashes, and starts on boot. I tested it by killing the app with pkill, then rebooting the server, and it came back both times.

My browser couldn't reach the app, even though curl on the server worked. Three things all have to be true for the browser to reach the app: the app is running, it listens on all addresses (--host 0.0.0.0, not just localhost), and the port is open in the firewall. Port 8000 wasn't open. I added a firewall rule for it, restricted to my IP.

I almost locked myself out of the server. While adding the port 8000 rule, I started editing my existing SSH rule instead of adding a new one. Changing it would have removed SSH access entirely. Lesson: add new firewall rules instead of editing the one you're relying on. (The AWS console would still have let me fix it, since it's a separate way in.)

I ran commands on the wrong machine. I tried gh pr merge on the server and systemctl on my Mac. The rule I learned: my Mac writes code (commits, PRs), GitHub stores it, and the server runs it (pull, restart). The terminal prompt shows which machine I'm on.

I ran git pull on the server, but my change wasn't there. My PR wasn't merged yet. The server only pulls main, so unmerged code never reaches it. That's the point: the PR is the gate.

A junk file (**pycache**) got committed. My .gitignore was missing it. I removed it from Git with git rm -r --cached **pycache** and fixed the commit with git commit --amend before pushing.

SSH said "Connection reset" right after a reboot. Different from a hang: "reset" means I reached the server, but SSH wasn't ready yet. The server was still booting. Waiting a minute fixed it.

SSH stopped working on a different Wi-Fi. A new network means a new public IP, which the firewall doesn't know. I used my phone's hotspot and added its IP temporarily, then removed it afterward.

Questions that took me a while to understand

Why does the server need to accept connections from the internet? Isn't it just running code? A web app's whole job is to answer requests from outside: browsers, phones, other apps. Without a way in, nothing could ever use it.

Does pushing to GitHub update the server? No. Pushing only updates GitHub. The server keeps running the old code until something tells it to pull and restart. Right now that's my deploy script. Doing it automatically on every merge is called continuous deployment (CI/CD), my next step.

Auto-restart vs. auto-deploy? systemd gives me auto-restart (crashes, reboots, closed SSH sessions). It does not auto-deploy. New code still only goes live when I run the deploy script.

If my SSH key already proves it's me, why also restrict by IP? Defense in depth. If my key ever leaked, an attacker would still need to be on my network. And the firewall stops internet bots, which constantly scan for open SSH ports, from even reaching the server. The firewall checks first, then the key.

What's the difference between a private IP and a private key? Totally different things that share a word. A private IP is an address inside AWS's network (where). A private key is a secret file that proves who I am (who).

What's a port, and what does /32 mean? A port is a numbered door a program listens on: SSH listens on 22, my app on 8000. One server, many doors. /32 in a firewall rule means "exactly this one address." /0 would mean the whole internet.

What's next
Automate deploys with GitHub Actions (CI/CD), so merging a PR deploys automatically
Put the app behind a domain name with HTTPS (Caddy or nginx), so nobody has to type :8000
