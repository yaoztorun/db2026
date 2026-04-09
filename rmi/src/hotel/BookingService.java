package hotel;

import java.rmi.Remote;
import java.rmi.RemoteException;
import java.time.LocalDate;
import java.util.Set;

public interface BookingService extends Remote {

	boolean isRoomAvailable(Integer roomNumber, LocalDate date) throws RemoteException;

	void addBooking(BookingDetail bookingDetail) throws RemoteException;

	Set<Integer> getAvailableRooms(LocalDate date) throws RemoteException;

	Set<Integer> getAllRooms() throws RemoteException;
}
