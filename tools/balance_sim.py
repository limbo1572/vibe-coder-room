"""Бот-гравець Vibe Coder Tycoon. Усі формули — 1:1 з game_state.gd (HEAD: prestige money reset + kickstart).
Мета: час кожного циклу престижу. Критерій здоров'я: ріст часу циклу <= x1.5."""
import math

CLICKS_PER_SEC = 1.0          # ледачий гравець
DEPLOY_EVERY = 15.0           # деплой кожні 15с
PAYBACK_HORIZON = 900.0          # окупнiсть до 15хв — гравець купує охочiше

GENS = [("stackoverflow",5,0.2),("chatgpt",100,1.0),("junior",500,4.0),
        ("youtube_senior",3000,20.0),("ai_army",20000,120.0)]
CLICK_ADD = [("mech_keyboard",50,1.0),("autocomplete",2000,5.0)]
CLICK_MULT = [("two_hands",300,2.0)]   # max 1
QA = [("linter",200,0.5),("unit_tests",1500,3.0),("qa_engineer",10000,15.0)]
DEPLOYU = [("cicd",800,0.05),("cloud_hosting",5000,0.15)]

# дерево: id -> (cost, root_req, kind, value)
TREE = {"sk_fast_fingers":(1,1,"click_mult",1.5),"sk_mech_kb":(2,1,"auto_click",1.0),
        "sk_different":(3,3,"click_mult",2.5),"sk_autocomplete":(1,1,"sec_mult",1.3),
        "sk_bg_agent":(2,1,"offline",0),"sk_generate_all":(4,4,"sec_mult",3.0),
        "sk_linter":(1,2,"qa_mult",1.5),"sk_one_test":(2,2,"bug_rate",0.7),
        "sk_auto_qa":(3,4,"auto_qa",2.0),"sk_seed":(1,2,"start_money",500.0),
        "sk_cloud_discount":(2,2,"cost_mult",0.9),"sk_series_b":(3,5,"deploy_mult",1.5)}
TOOLS_BRANCH = {"sk_ide":(1,1,"sec_mult",1.5),"sk_dotfiles":(2,3,"sec_mult",2.0),
                "sk_orchestrator":(4,5,"sec_mult",3.0)}
# пріоритет витрат очок бота: пасив-буст > корінь > решта
SPEND_ORDER = ["sk_autocomplete","sk_ide","sk_fast_fingers","sk_linter","sk_dotfiles",
               "sk_one_test","sk_generate_all","sk_mech_kb","sk_auto_qa",
               "sk_orchestrator","sk_seed","sk_cloud_discount","sk_different","sk_series_b"]

def root_cost(level, flat): return 1 if flat else 1 + level // 3

class Sim:
    def __init__(self, tools=False, flat_root=False):
        self.tree = dict(TREE); self.flat=flat_root
        if tools: self.tree.update(TOOLS_BRANCH)
        self.points=0; self.root=0; self.owned_sk=set()
        self.prestige_count=0; self.results=[]
        self.kickstart_active = False
        self.reset_run()
    def reset_run(self):
        self.loc=0.0; self.money=0.0; self.bugs=0.0
        self.up={}
        if "sk_seed" in self.owned_sk: self.money=500.0
    # --- стати з recalculate_stats ---
    def stats(self):
        lps=0.0; lpc=1.0; qa=0.0; rate=0.10
        for i,(n,b,v) in enumerate(GENS): lps+=v*self.up.get(n,0)
        for n,b,v in CLICK_ADD: lpc+=v*self.up.get(n,0)
        for n,b,v in CLICK_MULT: lpc*=v**min(self.up.get(n,0),1)
        for n,b,v in QA: qa+=v*self.up.get(n,0)
        for n,b,v in DEPLOYU: rate+=v*self.up.get(n,0)
        sec_mult=1.0; click_mult=1.0; qa_mult=1.0; deploy_mult=1.0
        bug_mult=1.0; auto_click=0.0; auto_qa=0.0
        for s in self.owned_sk:
            c,r,kind,v=self.tree[s]
            if kind=="sec_mult": sec_mult*=v
            elif kind=="click_mult": click_mult*=v
            elif kind=="qa_mult": qa_mult*=v
            elif kind=="deploy_mult": deploy_mult*=v
            elif kind=="bug_rate": bug_mult*=v
            elif kind=="auto_click": auto_click+=v
            elif kind=="auto_qa": auto_qa+=v
        trial = 2.0 if self.prestige_count == 0 else 1.0
        kick = 2.0 if self.kickstart_active else 1.0
        pm = 1.25**self.root * trial * kick
        cost_mult=0.9 if "sk_cloud_discount" in self.owned_sk else 1.0
        return dict(lps=lps*sec_mult, lpc=lpc*click_mult, qa=qa*qa_mult,
                    rate=rate*deploy_mult, pm=pm, bug_mult=bug_mult,
                    auto_click=auto_click, auto_qa=auto_qa, cost_mult=cost_mult)
    def prod(self):
        return max(0.1, min(1.0, 1.0 - self.bugs/(self.bugs+100.0)))
    def cost(self,base,owned,cm): return base*(1.15**owned)*cm
    def income_per_sec(self,s):
        p=self.prod()
        thru=(s["lps"]+(CLICKS_PER_SEC+s["auto_click"])*s["lpc"])*s["pm"]*p
        return thru*s["rate"]*math.sqrt(p), thru
    def try_buy(self,s):
        inc,thru=self.income_per_sec(s)
        best=None;bestpb=PAYBACK_HORIZON
        p=self.prod()
        for n,b,v in GENS:
            c=self.cost(b,self.up.get(n,0),s["cost_mult"])
            sm=1.0
            for sk in self.owned_sk:
                if self.tree[sk][2]=="sec_mult": sm*=self.tree[sk][3]
            d=v*sm*s["pm"]*p*s["rate"]*math.sqrt(p)
            if d>0 and c/d<bestpb and c<=self.money: best=(n,c);bestpb=c/d
        for n,b,v in CLICK_ADD:
            c=self.cost(b,self.up.get(n,0),s["cost_mult"])
            cm=1.0
            for n2,b2,v2 in CLICK_MULT: cm*=v2**min(self.up.get(n2,0),1)
            for sk in self.owned_sk:
                if self.tree[sk][2]=="click_mult": cm*=self.tree[sk][3]
            d=(CLICKS_PER_SEC+s["auto_click"])*v*cm*s["pm"]*p*s["rate"]*math.sqrt(p)
            if d>0 and c/d<bestpb and c<=self.money: best=(n,c);bestpb=c/d
        for n,b,v in CLICK_MULT:
            if self.up.get(n,0)>=1: continue
            c=self.cost(b,0,s["cost_mult"])
            d=(CLICKS_PER_SEC+s["auto_click"])*s["lpc"]*(v-1)*s["pm"]*p*s["rate"]*math.sqrt(p)
            if d>0 and c/d<bestpb and c<=self.money: best=(n,c);bestpb=c/d
        for n,b,v in DEPLOYU:
            c=self.cost(b,self.up.get(n,0),s["cost_mult"])
            d=thru*v
            if d>0 and c/d<bestpb and c<=self.money: best=(n,c);bestpb=c/d
        # QA: якщо приток багів > QA, prod деградує до 0.1 і дохід вмирає.
        # Цінність QA = різниця доходу між "здоровою" prod (0.9) і поточною траєкторією.
        influx=(s["lps"]*0.03+(CLICKS_PER_SEC+s["auto_click"])*s["lpc"]*0.05)*s["pm"]*p*s["bug_mult"]
        qa_total=s["qa"]+s["auto_qa"]
        if qa_total < influx*1.1 or p<0.85:
            ph=0.9
            inc_h=(s["lps"]+(CLICKS_PER_SEC+s["auto_click"])*s["lpc"])*s["pm"]*ph*s["rate"]*math.sqrt(ph)
            d=max(inc_h-inc, inc*0.25, 0.01)
            for n,b,v in QA:
                c=self.cost(b,self.up.get(n,0),s["cost_mult"])
                if c/d<bestpb and c<=self.money: best=(n,c);bestpb=c/d
        if best:
            self.money-=best[1]; self.up[best[0]]=self.up.get(best[0],0)+1
            return True
        return False
    def spend_points(self):
        moved=True
        while moved:
            moved=False
            for sk in SPEND_ORDER:
                if sk in self.tree and sk not in self.owned_sk:
                    c,rr,_,_=self.tree[sk]
                    if self.root>=rr and self.points>=c:
                        self.points-=c; self.owned_sk.add(sk); moved=True
            rc=root_cost(self.root,self.flat)
            # качаємо корінь, якщо він відкриє щось або дає мульт і є очки
            if self.points>=rc:
                self.points-=rc; self.root+=1; moved=True
    def run_cycle(self, max_hours=24):
        threshold=10_000.0*(3.0**self.prestige_count)
        t=0.0; dt=1.0; since_deploy=0.0
        while t<max_hours*3600:
            s=self.stats()
            p=self.prod()
            gain=s["lps"]*s["pm"]*p*dt
            self.loc+=gain; self.bugs+=gain*0.03*s["bug_mult"]
            cg=(CLICKS_PER_SEC+s["auto_click"])*s["lpc"]*s["pm"]*p*dt
            self.loc+=cg; self.bugs+=cg*0.05*s["bug_mult"]
            self.bugs=max(0.0,self.bugs-(s["qa"]+s["auto_qa"])*dt)
            since_deploy+=dt
            if since_deploy>=DEPLOY_EVERY and self.loc>0:
                self.money+=self.loc*s["rate"]*s["pm"]*math.sqrt(self.prod())
                self.loc=0.0; since_deploy=0.0
                if self.kickstart_active and self.money >= 10_000.0:
                    self.kickstart_active = False
            while self.try_buy(self.stats()): pass
            if self.money>=threshold:
                self.points+=1; self.prestige_count+=1
                self.results.append(t/60.0)
                self.spend_points(); self.reset_run()
                self.kickstart_active = True
                return True
            t+=dt
        self.results.append(float("inf"))
        return False

def run(label,tools=False,flat=False,n=8):
    s=Sim(tools,flat)
    print(f"\n== {label} ==")
    print(f"{'cycle':>5} {'поріг $':>12} {'хв':>8} {'ріст':>6}  дерево")
    prev=None
    for i in range(n):
        ok=s.run_cycle()
        m=s.results[-1]
        if not ok: print(f"{i+1:>5} {'10k*3^'+str(i):>12} {'>24год':>8}"); break
        g=f"x{m/prev:.2f}" if prev else "  —"
        print(f"{i+1:>5} {10000*3**i:>12,.0f} {m:>8.1f} {g:>6}  root={s.root} skills={len(s.owned_sk)}")
        prev=m

if __name__ == "__main__":
    run("A: поточний білд (корінь 1.25, ескалація вартості)")
    run("C: + гілка інструментів (x1.5/x2.0/x3.0)", tools=True)
    run("D: гілка + плоский корінь", tools=True, flat=True)
