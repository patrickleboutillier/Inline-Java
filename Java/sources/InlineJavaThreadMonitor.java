package org.perl.inline.java ;

import java.util.* ;


class InlineJavaThreadMonitor {
	static ThreadGroup root = null ;
	static {
		ThreadGroup tg = Thread.currentThread().getThreadGroup() ;
		while (tg != null){
			tg = tg.getParent() ;
		}
		root = tg ;
	}

	private Thread active_threads = null ;


	InlineJavaThreadMonitor(){
		active_threads = GetActiveThreads() ;
	}


	private Thread[] GetActiveThreads(){
		int size_est = root.activeCount() * 2 ;
		Thread list[] = new Thread[size_est] ;

		int size = root.enumerate(list) ;
		Thread ret[] = new Thread[size] ;
		for (int i = 0 ; i < size ; i++){
			ret[i] = list[i] ;
		}
	
		return ret ;	
	}


	public Thread[] GetNewThreads(){
		Thread current_threads[] = GetActiveThreads() ;
		int nb_new = current_threads.length - active_threads.length ;
		if (nb_new > 0){
			Thread ret[] = new Thread[nb_new] ;
			int idx = 0 ;
			for (int i = 0 ; i < current_threads.length ; i++){
				boolean found = false ;
				for (int j = 0 ; j < active_threads.length ; j++){
					if (active_threads[j] = current_threads[i]){
						found = true ;
						break ;
					}
				}
				if (! found){
					ret[idx] = current_threads[i] ;
					idx++ ;
				}
		}
		else{
			return new Thread [] {} ;
		}
	}
}
