package staff;

import hotel.BookingManager;
import hotel.BookingManagerInterface;

import java.rmi.Naming;
import java.rmi.Remote;
import java.rmi.server.UnicastRemoteObject;

public class BookingServer {
    public static void main(String[] args) throws Exception {
        System.setProperty("java.rmi.server.hostname", "yigit.switzerlandnorth.cloudapp.azure.com");

        BookingManager manager = new BookingManager();
        Remote stub = UnicastRemoteObject.exportObject(manager, 2001);

        Naming.rebind("rmi://0.0.0.0:1099/BookingManager", stub);

        System.out.println("BookingManager Server running...");
        System.out.println("List of rooms (room ID) in the hotel " + manager.getAllRooms());
    }
}
