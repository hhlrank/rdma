function dx = fluid2_test(t,x,lag_matrix)
    global Kmax;
    global Kmin;
    global numFlows;
    global numCalls;
    
    % matrix x:
    % 1: rc1
    % 2: rt1
    % 3: alpha1
    % 4: rc2
    % 5: rt2
    % 6: alpha2
    % ...
    % 3*numFlows+1: queue
    
    % lag matrix: 
    % (:,1) is t-t' for flow 1
    % (:,2) is t-t' for flow 2
    % ....

    dx = zeros(3*numFlows+1,1);
    
    %
    % marking probability
    %
    p = CalculateP(t,lag_matrix(end,1),Kmin,Kmax);
    
    %
    % rates and alpha
    %
    for i = 1:3:3*numFlows
        % The model cannot correctly handle the case of prevRC = 0. So we stay at 0. 
        if (x(i) == 0 && lag_matrix(i, 1) == 0)
            dx(i) = 0;
            dx(i+1) = 0;
        else
            [a,b,c,d,e] = IntermediateTerms(p, lag_matrix(i, 1), x(i), t, i);
            % rc
            dx(i) =  RCDelta(x(i), x(i+1), x(i+2), lag_matrix(i, 1), a, b, d);
            % rt
            dx(i+1) = RTDelta(x(i), x(i+1), lag_matrix(i, 1), a, c, e);
        end
        % alpha
        dx(i+2) = AlphaDelta(x(i+2), lag_matrix(i, 1), p);
    end
    
    %
    % Queue
    %
    rates = x(1:3:3*numFlows);
    dx(end) = QueueDelta(x(end), rates);
    numCalls = numCalls +1;
    if (mod(numCalls, 1000) == 0)
        fprintf ('%g %d\n', t, numCalls);
    end
    
end

% 7: queue
% 6: alpha2
% 5: rt2
% 4: rc2 
% 3: alpha1
% 2: rt1
% 1: rc1

function rcDelta = RCDelta(currRC, currRT, currAlpha, prevRC, a, b, d)
    global tau;
    global C;
   
    rcDelta = -1*currRC*currAlpha*a/(2*tau) + (currRT-currRC)*prevRC*b/2 + (currRT-currRC)*prevRC*d/2;
    
    % rate cannot exceed C.
    if (currRC >= C && rcDelta > 0)
        rcDelta = 0;
    end
end

function rtDelta = RTDelta(currRC, currRT, prevRC, a, c, e)
    global tau;
    global Rai;
    global C;
    
    rtDelta = -1*(currRT-currRC)*a/(tau) + Rai*prevRC*c + Rai*prevRC*e;
    
    % rate cannot exceed C.
    if (currRT >= C && rtDelta > 0)
        rtDelta = 0;
    end
    
end

function alphaDelta = AlphaDelta(currentAlpha, prevRC, p)
    global tauprime;
    global g;
    alphaDelta = g * ((1-(1-p)^(tauprime*prevRC))-currentAlpha) / tauprime;
end

function queueDelta = QueueDelta(currentQueue, rates)
    global C;
    queueDelta = sum(rates) - C;
    if (currentQueue <= 0)
        queueDelta = max(0, queueDelta);
    end
    if (currentQueue > 10000*8 && queueDelta > 0)
        queueDelta = 0;
    end
end

function p = CalculateP(t, q, kmin, kmax)
    global pmax;
    if (t >= 0)
        if q <= kmin
            p = 0;
        else if q <= kmax
                p = (q-kmin)/(kmax-kmin)*pmax;
            else % q > lmax
                p = 1;
            end
        end
    else 
        p = 1;
    end 
end

function [a, b, c, d, e] = IntermediateTerms(p, prevRC, currRC, t, i)
    global tau;
    global B;
    global F;
    global timer;   
    if p == 0
            a = 0;
            b = 1/B;
            c = b;
            if (prevRC == 0)
                d = 0;
            else 
                d = 1/(timer*prevRC);
            end
            e = d;
        else if p == 1
                a = 1;
                b = 0;
                c = 0;
                d = 0;
                e = 0;
            else    
                a = 1-(1-p)^(tau*prevRC);   
                b = p/((1-p)^(-B)-1);
                c = b*((1-p)^(F*B));
                d = p/((1-p)^(-timer*prevRC)-1);
                if (isinf(d))
                    d  = 1/(timer*prevRC);
                    e = d;
                else
                    e = d*((1-p)^(F*timer*prevRC));
                end
            end
    end
    if (isnan(a) || isnan(b) || isnan(c) || isnan(d) || isinf(d) || isinf(e))
        fprintf (' *************** ERROR ***********************\n');
        fprintf ('%i ', [p prevRC currRC t i a b c d e]);
        fprintf ('\n');
        a = 0; 
        b = 1/B;
        if (prevRC == 0)
           d = 0;
        else 
           d = 1/(timer*prevRC);
        end
        e = d;
        
    end
end

