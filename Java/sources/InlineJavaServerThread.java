import java.io.* ;
import java.net.* ;
import java.util.* ;


class InlineJavaServerThread extends Thread {
	InlineJavaServer ijs ;
	Socket client ;
	BufferedReader br ;
	BufferedWriter bw ;

	InlineJavaServerThread(InlineJavaServer _ijs, Socket _client) throws IOException {
		super() ;
		client = _client ;
		ijs = _ijs ;

		br = new BufferedReader(
			new InputStreamReader(client.getInputStream())) ;
		bw = new BufferedWriter(
			new OutputStreamWriter(client.getOutputStream())) ;
	}


	public void run(){
		try {
			ijs.AddThread(getName()) ;

			while (true){
				String cmd = br.readLine() ;

				String resp = ijs.ProcessCommand(cmd) ;
				if (resp != null){
					bw.write(resp) ;
					bw.flush() ;
				}
				else {
					break ;
				}
			}
		}
		catch (IOException e){
			System.err.println("IO error: " + e.getMessage()) ;
		}
		finally {
			ijs.RemoveThread(getName()) ;
		}
	}
}
