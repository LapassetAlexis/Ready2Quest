from b_wary import session
import random
random.seed(2);R=400
for fl in (.25,.3,.4,.5,.55,.6):
    for ns in (1,10):
        c=sum(session(240,ns,1,floor=fl) for _ in range(R))/R
        print(f"floor {fl} species {ns}: {c:.1f}")
print("no wariness:",sum(session(240,1,0) for _ in range(R))/R)
